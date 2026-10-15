import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Called once for each accepted file. Uploads run sequentially.
typedef UploadCallback = Future<void> Function(Uint8List data, String name);

enum ConcurrentDropPolicy {
  /// Decline a new batch while another upload is processing.
  reject,

  /// Disable both dropping and file selection while processing.
  disable,

  /// Accept new batches and upload them in arrival order.
  queue,
}

enum DroppedDirectoryPolicy {
  /// Skip directories, but process separately dropped files.
  ignore,

  /// Reject the whole batch if it contains any directory.
  reject,

  /// Walk all dropped directories and upload their files (relative paths kept).
  includeFiles,
}

enum UploadAreaFailureKind {
  busy,
  multipleFiles,
  directoryDisabled,
  noFiles,
  tooLarge,
  invalidExtension,
  failed,
}

/// A structured error; use [kind] rather than parsing the localized message.
@immutable
class UploadAreaFailure {
  const UploadAreaFailure({
    required this.kind,
    required this.message,
    this.fileName,
    this.cause,
  });

  final UploadAreaFailureKind kind;
  final String message;
  final String? fileName;
  final Object? cause;

  @override
  String toString() => message;
}

/// The widget's built-in localized strings.
///
/// Common languages are bundled. Other locales fall back to English.
/// Per-instance [DragAndDropUploadArea.strings] overrides the defaults.
@immutable
class UploadAreaStrings {
  const UploadAreaStrings({
    required this.uploadFile,
    required this.uploading,
    required this.fileUploaded,
    required this.uploadError,
    required this.uploadInProgress,
    required this.onlyOneFile,
    required this.fileTooLarge,
    required this.fileTypeNotAllowed,
    required this.directoryUploadsDisabled,
    required this.noFilesFound,
  });

  final String uploadFile;
  final String uploading;
  final String fileUploaded;
  final String uploadError;
  final String uploadInProgress;
  final String onlyOneFile;
  final String fileTooLarge;
  final String fileTypeNotAllowed;
  final String directoryUploadsDisabled;
  final String noFilesFound;

  static const en = UploadAreaStrings(
    uploadFile: 'Upload file',
    uploading: 'Uploading…',
    fileUploaded: 'File uploaded',
    uploadError: 'Upload error',
    uploadInProgress: 'An upload is already in progress',
    onlyOneFile: 'Only one file is allowed',
    fileTooLarge: 'File exceeds the maximum size',
    fileTypeNotAllowed: 'File type is not allowed',
    directoryUploadsDisabled: 'Directory uploads are disabled',
    noFilesFound: 'No files found',
  );

  static final Map<String, UploadAreaStrings> _translations =
      _parseTranslations();

  static UploadAreaStrings forLocale(Locale? locale) {
    if (locale == null) return en;
    final language = locale.languageCode.toLowerCase();
    final script = locale.scriptCode?.toLowerCase();
    final country = locale.countryCode?.toLowerCase();
    if (script != null && country != null) {
      final exact = _translations['${language}_${script}_$country'];
      if (exact != null) return exact;
    }
    if (script != null) {
      final byScript = _translations['${language}_$script'];
      if (byScript != null) return byScript;
    }
    if (country != null) {
      final byCountry = _translations['${language}_$country'];
      if (byCountry != null) return byCountry;
    }
    return _translations[language] ?? en;
  }

  static UploadAreaStrings of(BuildContext context) =>
      forLocale(Localizations.maybeLocaleOf(context));

  static Map<String, UploadAreaStrings> _parseTranslations() {
    final result = <String, UploadAreaStrings>{'en': en};
    for (final row in _localizedMessages.split('\n')) {
      final line = row.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final parts = line.split('|');
      if (parts.length != 11) {
        throw FormatException('Expected locale + 10 messages: $line');
      }
      final [
        language,
        uploadFile,
        uploading,
        fileUploaded,
        uploadError,
        uploadInProgress,
        onlyOneFile,
        fileTooLarge,
        fileTypeNotAllowed,
        directoryUploadsDisabled,
        noFilesFound,
      ] = parts;
      if (parts.any((part) => part.trim().isEmpty)) {
        throw FormatException('Empty localized message: $language');
      }
      result[language.trim().toLowerCase()] = UploadAreaStrings(
        uploadFile: uploadFile.trim(),
        uploading: uploading.trim(),
        fileUploaded: fileUploaded.trim(),
        uploadError: uploadError.trim(),
        uploadInProgress: uploadInProgress.trim(),
        onlyOneFile: onlyOneFile.trim(),
        fileTooLarge: fileTooLarge.trim(),
        fileTypeNotAllowed: fileTypeNotAllowed.trim(),
        directoryUploadsDisabled: directoryUploadsDisabled.trim(),
        noFilesFound: noFilesFound.trim(),
      );
    }
    return Map.unmodifiable(result);
  }
}

class DragAndDropUploadArea extends StatefulWidget {
  const DragAndDropUploadArea({
    super.key,
    required this.onUpload,
    this.buttonLabel,
    this.hintText,
    this.hintTooltip,
    this.buttonIcon,
    this.strings,
    this.onError,
    this.onSuccess,
    this.allowMultiple = false,
    this.allowedExtensions,
    this.maxFileSize,
    this.concurrentDropPolicy = ConcurrentDropPolicy.queue,
    this.directoryPolicy = DroppedDirectoryPolicy.ignore,
  }) : assert(maxFileSize == null || maxFileSize > 0);

  final UploadCallback onUpload;

  /// Override built-in translations, or leave null to use the app locale.
  final UploadAreaStrings? strings;

  /// If null, show a ScaffoldMessenger SnackBar for each error.
  final ValueChanged<UploadAreaFailure>? onError;

  /// If null, show a ScaffoldMessenger SnackBar for each successful upload.
  final ValueChanged<String>? onSuccess;

  final String? buttonLabel;
  final String? hintText;
  final String? hintTooltip;
  final Icon? buttonIcon;
  final bool allowMultiple;

  /// Case-insensitive extensions, with or without a leading dot.
  /// Compound extensions such as 'tar.gz' are supported.
  /// Null or empty accepts any extension.
  final List<String>? allowedExtensions;

  /// Maximum file size in bytes; null means unlimited.
  final int? maxFileSize;
  final ConcurrentDropPolicy concurrentDropPolicy;
  final DroppedDirectoryPolicy directoryPolicy;

  @override
  DragAndDropUploadAreaState createState() => DragAndDropUploadAreaState();
}

class DragAndDropUploadAreaState extends State<DragAndDropUploadArea> {
  final Queue<_UploadFile> _queue = Queue<_UploadFile>();
  bool _hovering = false;
  bool _pickingFile = false;
  bool _processing = false;

  UploadAreaStrings get _strings =>
      widget.strings ?? UploadAreaStrings.of(context);

  bool get _blockInteractions =>
      widget.concurrentDropPolicy == ConcurrentDropPolicy.disable &&
      (_processing || _pickingFile);

  bool get _rejectWhenBusy =>
      widget.concurrentDropPolicy == ConcurrentDropPolicy.reject &&
      (_processing || _pickingFile);

  Set<String> get _extensions => {
    for (final extension in widget.allowedExtensions ?? const <String>[])
      if (extension.trim().isNotEmpty)
        extension.trim().replaceFirst(RegExp(r'^\.'), '').toLowerCase(),
  };

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      enable: !_blockInteractions,
      onDragEntered: (_) {
        if (mounted && !_blockInteractions) setState(() => _hovering = true);
      },
      onDragExited: (_) {
        if (mounted) setState(() => _hovering = false);
      },
      onDragDone: (details) => _handleDrop(details.files),
      child: _buildInner(),
    );
  }

  Widget _buildInner() {
    final strings = _strings;
    final theme = Theme.of(context);
    final disabled = _pickingFile || _blockInteractions;
    final hasButton = widget.buttonIcon != null || widget.buttonLabel != null;
    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: _hovering
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: _hovering ? 3 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: hasButton
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: disabled ? null : _pickFile,
                  icon: _processing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : widget.buttonIcon ?? const Icon(Icons.upload_file),
                  label: Text(
                    _processing
                        ? strings.uploading
                        : widget.buttonLabel ?? strings.uploadFile,
                  ),
                ),
                if (widget.hintText != null) ...[
                  const SizedBox(height: 8),
                  Tooltip(
                    message: widget.hintTooltip ?? widget.hintText!,
                    child: Text(
                      widget.hintText!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_processing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.upload_file),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _processing ? strings.uploading : strings.uploadFile,
                  ),
                ),
              ],
            ),
    );
    return hasButton
        ? content
        : InkWell(onTap: disabled ? null : _pickFile, child: content);
  }

  void _handleDrop(List<DropItem> items) {
    if (!mounted) return;
    setState(() => _hovering = false);
    if (_blockInteractions) return;
    if (_rejectWhenBusy) {
      _report(UploadAreaFailureKind.busy);
      return;
    }
    try {
      final pending = Queue<({DropItem item, String prefix})>.from(
        items.map((item) => (item: item, prefix: '')),
      );
      final files = <_UploadFile>[];
      var ignoredDirectories = false;
      while (pending.isNotEmpty) {
        final (:item, :prefix) = pending.removeFirst();
        if (item is DropItemDirectory) {
          if (widget.directoryPolicy == DroppedDirectoryPolicy.ignore) {
            ignoredDirectories = true;
            continue;
          }
          if (widget.directoryPolicy == DroppedDirectoryPolicy.reject) {
            _report(UploadAreaFailureKind.directoryDisabled);
            return;
          }
          for (final child in item.children) {
            pending.add((item: child, prefix: '$prefix${item.name}/'));
          }
        } else if (item is DropItemFile) {
          files.add(
            _UploadFile(
              name: '$prefix${item.name}',
              length: item.length,
              read: item.readAsBytes,
            ),
          );
        }
      }
      if (files.isEmpty) {
        _report(
          ignoredDirectories
              ? UploadAreaFailureKind.directoryDisabled
              : UploadAreaFailureKind.noFiles,
        );
        return;
      }
      _submit(files);
    } catch (error) {
      _report(UploadAreaFailureKind.failed, cause: error);
    }
  }

  Future<void> _pickFile() async {
    if (_pickingFile || _blockInteractions) return;
    if (_rejectWhenBusy) {
      _report(UploadAreaFailureKind.busy);
      return;
    }
    setState(() => _pickingFile = true);
    try {
      final extensions = _extensions.toList()..sort();
      final type = extensions.isEmpty ? FileType.any : FileType.custom;
      final allowed = extensions.isEmpty ? null : extensions;
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowed,
        allowMultiple: widget.allowMultiple,
        withReadStream: true,
      );
      final picked = result?.files ?? <PlatformFile>[];
      if (!mounted || picked.isEmpty) return;
      final files = <_UploadFile>[
        for (final file in picked)
          _UploadFile(
            name: file.name,
            length: () async => file.size,
            read: () async {
              if (file.bytes case final bytes?) return bytes;
              if (file.readStream case final stream?) {
                final buffer = BytesBuilder(copy: false);
                await for (final chunk in stream) {
                  buffer.add(chunk);
                }
                return buffer.takeBytes();
              }
              return file.xFile.readAsBytes();
            },
          ),
      ];
      _submit(files);
    } catch (error) {
      _report(UploadAreaFailureKind.failed, cause: error);
    } finally {
      if (mounted) setState(() => _pickingFile = false);
    }
  }

  void _submit(List<_UploadFile> files) {
    if (!mounted || files.isEmpty) return;
    if (!widget.allowMultiple && files.length > 1) {
      _report(UploadAreaFailureKind.multipleFiles);
      return;
    }
    if (_processing &&
        widget.concurrentDropPolicy != ConcurrentDropPolicy.queue) {
      _report(UploadAreaFailureKind.busy);
      return;
    }
    _queue.addAll(files);
    if (!_processing) {
      setState(() => _processing = true);
      unawaited(_processQueue());
    }
  }

  Future<void> _processQueue() async {
    try {
      while (_queue.isNotEmpty && mounted) {
        final file = _queue.removeFirst();
        try {
          if (!_allowedName(file.name)) {
            _report(UploadAreaFailureKind.invalidExtension, name: file.name);
            continue;
          }
          final size = await file.length();
          if (!mounted) break;
          if (_exceedsMaxSize(size)) {
            _report(UploadAreaFailureKind.tooLarge, name: file.name);
            continue;
          }
          final data = await file.read();
          if (!mounted) break;
          if (_exceedsMaxSize(data.length)) {
            _report(UploadAreaFailureKind.tooLarge, name: file.name);
            continue;
          }
          await widget.onUpload(data, file.name);
          if (mounted) _notifySuccess(file.name);
        } catch (error) {
          if (mounted) {
            _report(
              UploadAreaFailureKind.failed,
              name: file.name,
              cause: error,
            );
          }
        }
      }
    } finally {
      _queue.clear();
      _processing = false;
      if (mounted) setState(() {});
    }
  }

  bool _allowedName(String name) {
    final extensions = _extensions;
    if (extensions.isEmpty) return true;
    final basename = name.replaceAll('\\', '/').split('/').last.toLowerCase();
    return extensions.any((ext) => basename.endsWith('.$ext'));
  }

  bool _exceedsMaxSize(int? size) =>
      size != null && widget.maxFileSize != null && size > widget.maxFileSize!;

  void _report(UploadAreaFailureKind kind, {String? name, Object? cause}) {
    if (!mounted) return;
    final strings = _strings;
    final reason = switch (kind) {
      UploadAreaFailureKind.busy => strings.uploadInProgress,
      UploadAreaFailureKind.multipleFiles => strings.onlyOneFile,
      UploadAreaFailureKind.directoryDisabled =>
        strings.directoryUploadsDisabled,
      UploadAreaFailureKind.noFiles => strings.noFilesFound,
      UploadAreaFailureKind.tooLarge =>
        '${strings.fileTooLarge} (${widget.maxFileSize} bytes)',
      UploadAreaFailureKind.invalidExtension => strings.fileTypeNotAllowed,
      UploadAreaFailureKind.failed => cause?.toString() ?? strings.uploadError,
    };
    final failure = UploadAreaFailure(
      kind: kind,
      fileName: name,
      cause: cause,
      message:
          '${strings.uploadError}: '
          '${name == null ? '' : '$name: '}$reason',
    );
    if (widget.onError case final callback?) {
      callback(failure);
    } else {
      _showSnackBar(failure.message);
    }
  }

  void _notifySuccess(String name) {
    if (!mounted) return;
    if (widget.onSuccess case final callback?) {
      callback(name);
    } else {
      _showSnackBar('${_strings.fileUploaded}: $name');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _queue.clear();
    super.dispose();
  }
}

class _UploadFile {
  const _UploadFile({
    required this.name,
    required this.length,
    required this.read,
  });

  final String name;
  final Future<int?> Function() length;
  final Future<Uint8List> Function() read;
}

// Popular languages: en, vi, ru, de, fr, es, pt, it, zh, ja, ko, ar, hi, id.
// Unknown locales fall back to English; app strings can override defaults.
// One row = code | uploadFile | uploading | fileUploaded | uploadError |
// busy | onlyOneFile | tooLarge | invalidExtension | directoriesDisabled | noFiles.
// Keep this UTF-8 table next to the widget to make the source self-contained.
const _localizedMessages = r'''
vi|Tải tệp lên|Đang tải lên…|Đã tải tệp lên|Lỗi tải lên|Đang có tệp được tải lên|Chỉ được phép tải lên một tệp|Tệp vượt quá dung lượng tối đa|Loại tệp không được phép|Không cho phép tải thư mục lên|Không tìm thấy tệp
ru|Загрузить файл|Загрузка…|Файл загружен|Ошибка загрузки|Загрузка уже выполняется|Разрешён только один файл|Превышен максимальный размер файла|Недопустимый тип файла|Загрузка папок отключена|Файлы не найдены
de|Datei hochladen|Wird hochgeladen…|Datei hochgeladen|Uploadfehler|Ein Upload läuft bereits|Nur eine Datei ist erlaubt|Datei überschreitet die maximale Größe|Dateityp nicht erlaubt|Ordner-Uploads sind deaktiviert|Keine Dateien gefunden
fr|Téléverser un fichier|Téléversement…|Fichier téléversé|Erreur de téléversement|Un téléversement est déjà en cours|Un seul fichier est autorisé|La taille maximale est dépassée|Type de fichier non autorisé|Le téléversement de dossiers est désactivé|Aucun fichier trouvé
es|Subir archivo|Subiendo…|Archivo subido|Error al subir|Ya hay una carga en curso|Solo se permite un archivo|El archivo supera el tamaño máximo|Tipo de archivo no permitido|La subida de carpetas está desactivada|No se encontraron archivos
pt|Enviar arquivo|Enviando…|Arquivo enviado|Erro no envio|Já existe um envio em andamento|Apenas um arquivo é permitido|O arquivo excede o tamanho máximo|Tipo de arquivo não permitido|O envio de pastas está desativado|Nenhum arquivo encontrado
it|Carica file|Caricamento…|File caricato|Errore di caricamento|Un caricamento è già in corso|È consentito un solo file|Il file supera la dimensione massima|Tipo di file non consentito|Il caricamento delle cartelle è disabilitato|Nessun file trovato
zh|上传文件|正在上传…|文件已上传|上传错误|已有上传任务正在进行|仅允许一个文件|文件超过最大大小|不允许的文件类型|已禁用文件夹上传|未找到文件
ja|ファイルをアップロード|アップロード中…|ファイルをアップロードしました|アップロードエラー|アップロードが進行中です|選択できるファイルは1つだけです|ファイルが最大サイズを超えています|許可されていないファイル形式です|フォルダーのアップロードは無効です|ファイルが見つかりません
ko|파일 업로드|업로드 중…|파일 업로드 완료|업로드 오류|이미 업로드가 진행 중입니다|파일은 하나만 허용됩니다|파일이 최대 크기를 초과했습니다|허용되지 않는 파일 형식입니다|폴더 업로드가 비활성화되어 있습니다|파일을 찾을 수 없습니다
ar|رفع ملف|جارٍ الرفع…|تم رفع الملف|خطأ في الرفع|توجد عملية رفع قيد التنفيذ|يُسمح بملف واحد فقط|يتجاوز الملف الحجم الأقصى|نوع الملف غير مسموح به|تم تعطيل رفع المجلدات|لم يتم العثور على ملفات
hi|फ़ाइल अपलोड करें|अपलोड हो रहा है…|फ़ाइल अपलोड हुई|अपलोड में त्रुटि|अपलोड पहले से जारी है|केवल एक फ़ाइल की अनुमति है|फ़ाइल अधिकतम आकार से बड़ी है|फ़ाइल का प्रकार अनुमत नहीं है|फ़ोल्डर अपलोड बंद है|कोई फ़ाइल नहीं मिली
id|Unggah file|Mengunggah…|File berhasil diunggah|Kesalahan unggah|Unggahan sedang berlangsung|Hanya satu file yang diizinkan|File melebihi ukuran maksimum|Jenis file tidak diizinkan|Unggahan folder dinonaktifkan|Tidak ada file ditemukan
''';
