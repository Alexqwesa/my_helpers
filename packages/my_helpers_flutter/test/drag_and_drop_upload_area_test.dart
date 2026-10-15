import 'dart:async';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_helpers_flutter/my_helpers_flutter.dart';

DropItemFile file(String name, [List<int> bytes = const [1, 2, 3]]) =>
    DropItemFile.fromData(Uint8List.fromList(bytes), name: name, path: name);

void drop(WidgetTester tester, List<DropItem> files) {
  tester.widget<DropTarget>(find.byType(DropTarget)).onDragDone!(
    DropDoneDetails(
      files: files,
      localPosition: Offset.zero,
      globalPosition: Offset.zero,
    ),
  );
}

Future<void> mount(WidgetTester tester, DragAndDropUploadArea area) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: area)));

void main() {
  test('all bundled locales have strings and unknown locales use English', () {
    for (final code in [
      'vi',
      'ru',
      'de',
      'fr',
      'es',
      'pt',
      'it',
      'zh',
      'ja',
      'ko',
      'ar',
      'hi',
      'id',
    ]) {
      final strings = UploadAreaStrings.forLocale(Locale(code));
      expect(strings.uploadFile, isNotEmpty);
      expect(strings, isNot(same(UploadAreaStrings.en)));
    }
    expect(
      UploadAreaStrings.forLocale(const Locale('unknown')),
      same(UploadAreaStrings.en),
    );
    expect(UploadAreaStrings.forLocale(null), same(UploadAreaStrings.en));
  });

  testWidgets(
    'locale changes rebuild labels and instance strings override locale',
    (tester) async {
      final area = DragAndDropUploadArea(onUpload: (_, _) async {});
      Future<void> show(Locale locale, {UploadAreaStrings? strings}) =>
          tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => Localizations.override(
                  context: context,
                  locale: locale,
                  child: Scaffold(
                    body: strings == null
                        ? area
                        : DragAndDropUploadArea(
                            onUpload: (_, _) async {},
                            strings: strings,
                          ),
                  ),
                ),
              ),
            ),
          );
      await show(const Locale('en'));
      expect(find.text(UploadAreaStrings.en.uploadFile), findsOneWidget);
      await show(const Locale('vi'));
      expect(
        find.text(UploadAreaStrings.forLocale(const Locale('vi')).uploadFile),
        findsOneWidget,
      );
      await show(const Locale('vi'), strings: UploadAreaStrings.en);
      expect(find.text(UploadAreaStrings.en.uploadFile), findsOneWidget);
    },
  );

  testWidgets('uploads dropped bytes and reports success', (tester) async {
    final uploaded = <String>[];
    final successes = <String>[];
    Uint8List? receivedBytes;
    await mount(
      tester,
      DragAndDropUploadArea(
        onUpload: (bytes, name) async {
          receivedBytes = bytes;
          uploaded.add(name);
        },
        onSuccess: successes.add,
      ),
    );
    drop(tester, [file('report.pdf')]);
    await tester.pumpAndSettle();
    expect(uploaded, ['report.pdf']);
    expect(successes, uploaded);
    expect(receivedBytes, [1, 2, 3]);
  });

  testWidgets('rejects multiple files and empty drops', (tester) async {
    final errors = <UploadAreaFailure>[];
    await mount(
      tester,
      DragAndDropUploadArea(
        onUpload: (_, _) async => fail('Invalid batches must not upload'),
        onError: errors.add,
      ),
    );
    drop(tester, [file('a'), file('b')]);
    drop(tester, []);
    await tester.pump();
    expect(errors.map((e) => e.kind), [
      UploadAreaFailureKind.multipleFiles,
      UploadAreaFailureKind.noFiles,
    ]);
  });

  testWidgets(
    'validates compound extensions and size, then continues the batch',
    (tester) async {
      final errors = <UploadAreaFailure>[];
      final uploaded = <String>[];
      await mount(
        tester,
        DragAndDropUploadArea(
          allowMultiple: true,
          allowedExtensions: const [' .TAR.GZ ', 'pdf'],
          maxFileSize: 3,
          onUpload: (_, name) async => uploaded.add(name),
          onError: errors.add,
          onSuccess: (_) {},
        ),
      );
      drop(tester, [
        file('bad.exe'),
        file('large.pdf', [1, 2, 3, 4]),
        file('ARCHIVE.TAR.GZ'),
        file('exact.pdf'),
      ]);
      await tester.pumpAndSettle();
      expect(uploaded, ['ARCHIVE.TAR.GZ', 'exact.pdf']);
      expect(errors.map((e) => e.kind), [
        UploadAreaFailureKind.invalidExtension,
        UploadAreaFailureKind.tooLarge,
      ]);
      expect(errors.map((e) => e.fileName), ['bad.exe', 'large.pdf']);
    },
  );

  for (final policy in DroppedDirectoryPolicy.values) {
    testWidgets('directory policy: ${policy.name}', (tester) async {
      final uploaded = <String>[];
      final errors = <UploadAreaFailure>[];
      await mount(
        tester,
        DragAndDropUploadArea(
          allowMultiple: true,
          directoryPolicy: policy,
          onUpload: (_, name) async => uploaded.add(name),
          onSuccess: (_) {},
          onError: errors.add,
        ),
      );
      drop(tester, [
        file('loose.txt'),
        DropItemDirectory('folder', [
          file('inner.txt'),
          DropItemDirectory('sub', [file('deep.txt')], name: 'sub'),
        ], name: 'folder'),
      ]);
      await tester.pumpAndSettle();
      switch (policy) {
        case DroppedDirectoryPolicy.ignore:
          expect(uploaded, ['loose.txt']);
          expect(errors, isEmpty);
        case DroppedDirectoryPolicy.reject:
          expect(uploaded, isEmpty);
          expect(errors.single.kind, UploadAreaFailureKind.directoryDisabled);
        case DroppedDirectoryPolicy.includeFiles:
          expect(uploaded, [
            'loose.txt',
            'folder/inner.txt',
            'folder/sub/deep.txt',
          ]);
          expect(errors, isEmpty);
      }
    });
  }

  for (final policy in ConcurrentDropPolicy.values) {
    testWidgets('concurrent batch policy: ${policy.name}', (tester) async {
      final gate = Completer<void>();
      final uploaded = <String>[];
      final errors = <UploadAreaFailure>[];
      await mount(
        tester,
        DragAndDropUploadArea(
          concurrentDropPolicy: policy,
          onUpload: (_, name) async {
            uploaded.add(name);
            if (name == 'first') await gate.future;
          },
          onSuccess: (_) {},
          onError: errors.add,
        ),
      );
      drop(tester, [file('first')]);
      await tester.pump();
      expect(uploaded, ['first']);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<DropTarget>(find.byType(DropTarget)).enable,
        policy != ConcurrentDropPolicy.disable,
      );
      drop(tester, [file('second')]);
      await tester.pump();
      expect(uploaded, ['first']);
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        uploaded,
        policy == ConcurrentDropPolicy.queue ? ['first', 'second'] : ['first'],
      );
      expect(
        errors.map((e) => e.kind),
        policy == ConcurrentDropPolicy.reject
            ? [UploadAreaFailureKind.busy]
            : isEmpty,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  }

  testWidgets(
    'an upload failure preserves its cause and does not stop the queue',
    (tester) async {
      final cause = StateError('Server rejected file');
      final errors = <UploadAreaFailure>[];
      final successes = <String>[];
      await mount(
        tester,
        DragAndDropUploadArea(
          allowMultiple: true,
          onUpload: (_, name) async {
            if (name == 'bad') throw cause;
          },
          onSuccess: successes.add,
          onError: errors.add,
        ),
      );
      drop(tester, [file('bad'), file('good')]);
      await tester.pumpAndSettle();
      expect(errors.single.kind, UploadAreaFailureKind.failed);
      expect(errors.single.cause, same(cause));
      expect(errors.single.fileName, 'bad');
      expect(successes, ['good']);
    },
  );

  testWidgets(
    'disposal while uploading cancels queued files and notifications',
    (tester) async {
      final gate = Completer<void>();
      final uploaded = <String>[];
      await mount(
        tester,
        DragAndDropUploadArea(
          allowMultiple: true,
          onUpload: (_, name) async {
            uploaded.add(name);
            await gate.future;
          },
          onSuccess: (_) => fail('No notification after disposal'),
        ),
      );
      drop(tester, [file('first'), file('second')]);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      gate.complete();
      await tester.pump();
      expect(uploaded, ['first']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'default notifications display upload success and validation errors',
    (tester) async {
      await mount(tester, DragAndDropUploadArea(onUpload: (_, _) async {}));
      drop(tester, [file('done.txt')]);
      await tester.pumpAndSettle();
      expect(find.text('File uploaded: done.txt'), findsOneWidget);
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .clearSnackBars();
      await tester.pumpAndSettle();
      drop(tester, []);
      await tester.pumpAndSettle();
      expect(find.text('Upload error: No files found'), findsOneWidget);
    },
  );
  group('file picker', () {
    late _FakePicker picker;
    FilePicker? original;
    setUp(() {
      try {
        original = FilePicker.platform;
      } on Error {
        original = null;
      }
      picker = _FakePicker();
      FilePicker.platform = picker;
    });
    tearDown(() {
      if (original != null) FilePicker.platform = original!;
    });

    testWidgets('reads streamed files and forwards normalized picker options', (
      tester,
    ) async {
      picker.result = FilePickerResult([
        PlatformFile(
          name: 'report.pdf',
          size: 3,
          readStream: Stream.fromIterable([
            [1],
            [2, 3],
          ]),
        ),
      ]);
      final received = <List<int>>[];
      final names = <String>[];
      await mount(
        tester,
        DragAndDropUploadArea(
          buttonLabel: 'Select',
          hintText: 'PDF files',
          hintTooltip: 'Choose a PDF',
          allowedExtensions: const [' .PDF ', 'pdf'],
          allowMultiple: true,
          onUpload: (bytes, name) async {
            received.add(bytes);
            names.add(name);
          },
          onSuccess: (_) {},
        ),
      );
      expect(find.byTooltip('Choose a PDF'), findsOneWidget);
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      expect(received, [
        [1, 2, 3],
      ]);
      expect(names, ['report.pdf']);
      expect(picker.type, FileType.custom);
      expect(picker.extensions, ['pdf']);
      expect(picker.multiple, isTrue);
      expect(picker.readStream, isTrue);
    });

    testWidgets(
      'cancellation leaves the area usable and picker errors are reported',
      (tester) async {
        final errors = <UploadAreaFailure>[];
        await mount(
          tester,
          DragAndDropUploadArea(
            onUpload: (_, _) async =>
                fail('Cancelled selection must not upload'),
            onError: errors.add,
          ),
        );
        await tester.tap(find.text('Upload file'));
        await tester.pumpAndSettle();
        expect(errors, isEmpty);
        expect(picker.type, FileType.any);
        final cause = StateError('Picker unavailable');
        picker.error = cause;
        await tester.tap(find.text('Upload file'));
        await tester.pumpAndSettle();
        expect(picker.calls, 2);
        expect(errors.single.kind, UploadAreaFailureKind.failed);
        expect(errors.single.cause, same(cause));
      },
    );

    testWidgets(
      'checks actual byte length even if picker metadata underreports size',
      (tester) async {
        picker.result = FilePickerResult([
          PlatformFile(name: 'big.pdf', size: 1, bytes: Uint8List(4)),
        ]);
        final errors = <UploadAreaFailure>[];
        await mount(
          tester,
          DragAndDropUploadArea(
            maxFileSize: 3,
            onUpload: (_, _) async => fail('Oversized bytes must not upload'),
            onError: errors.add,
          ),
        );
        await tester.tap(find.text('Upload file'));
        await tester.pumpAndSettle();
        expect(errors.single.kind, UploadAreaFailureKind.tooLarge);
        expect(errors.single.fileName, 'big.pdf');
      },
    );
  });
}

class _FakePicker extends FilePicker {
  FilePickerResult? result;
  Object? error;
  FileType? type;
  List<String>? extensions;
  bool? multiple;
  bool? readStream;
  int calls = 0;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    calls++;
    this.type = type;
    extensions = allowedExtensions;
    multiple = allowMultiple;
    readStream = withReadStream;
    if (error case final cause?) throw cause;
    return result;
  }
}
