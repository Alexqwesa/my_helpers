import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'aloc.dart';
import 'app_diagnostics.dart';

/// Explicitly navigate here to review, clear, or manually export diagnostics.
/// No notification helpers are used here, including on export failure.
class AppDiagnosticsScreen extends StatefulWidget {
  const AppDiagnosticsScreen({super.key});

  @override
  State<AppDiagnosticsScreen> createState() => _AppDiagnosticsScreenState();
}

class _AppDiagnosticsScreenState extends State<AppDiagnosticsScreen> {
  late final StreamSubscription<Object?> _subscription;
  bool _exporting = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _subscription = appTalker.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _export() async {
    setState(() {
      _exporting = true;
      _status = null;
    });
    try {
      final path = await FilePicker.platform.saveFile(
        fileName: 'diagnostics.txt',
        type: FileType.custom,
        allowedExtensions: ['txt'],
        bytes: Uint8List.fromList(utf8.encode(AppDiagnostics.exportText())),
      );
      if (mounted && (kIsWeb || path != null)) {
        setState(
          () => _status = 'Export requested|Đã yêu cầu xuất|Экспорт запрошен',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _status =
              'Export failed. Try again.|Xuất thất bại. Thử lại.|Не удалось экспортировать. Повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = appTalker.history.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.aloc('Diagnostics|Chẩn đoán|Диагностика')),
        actions: [
          IconButton(
            tooltip: context.aloc('Clear history|Xóa lịch sử|Очистить историю'),
            icon: const Icon(Icons.delete_outline),
            onPressed: history.isEmpty
                ? null
                : () => setState(() {
                    AppDiagnostics.clear();
                    _status = null;
                  }),
          ),
          IconButton(
            tooltip: context.aloc(
              'Export diagnostics|Xuất chẩn đoán|Экспорт диагностики',
            ),
            icon: const Icon(Icons.download),
            onPressed: _exporting || history.isEmpty ? null : _export,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.aloc(
                'Memory only. Review for sensitive data before exporting.|Chỉ lưu trong bộ nhớ. Kiểm tra dữ liệu nhạy cảm trước khi xuất.|Только в памяти. Проверьте данные перед экспортом.',
              ),
            ),
          ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(context.aloc(_status!)),
            ),
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Text(
                      context.aloc(
                        'No diagnostics yet|Chưa có chẩn đoán|Диагностических записей нет',
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          history[index].generateTextMessage(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
