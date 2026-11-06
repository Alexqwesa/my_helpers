import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_helpers_flutter/my_helpers_flutter.dart';

void main() {
  late _ExportPicker picker;
  FilePicker? original;

  setUp(() {
    AppDiagnostics.configure(
      enabled: true,
      maxHistoryItems: 200,
      notificationLogging: true,
      useConsoleLogs: false,
    );
    AppDiagnostics.clear();
    try {
      original = FilePicker.platform;
    } catch (_) {
      original = null;
    }
    picker = _ExportPicker();
    FilePicker.platform = picker;
  });

  tearDown(() {
    if (original != null) FilePicker.platform = original!;
    AppDiagnostics.clear();
  });

  testWidgets(
    'empty screen does not export automatically; new logs appear live',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AppDiagnosticsScreen()));
      expect(find.text('No diagnostics yet'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.download))
            .onPressed,
        isNull,
      );
      expect(picker.calls, 0);
      AppDiagnostics.recordNotification('save.failed', level: LogLevel.error);
      await tester.pumpAndSettle();
      expect(find.textContaining('save.failed'), findsOneWidget);
      expect(picker.calls, 0);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      expect(find.text('No diagnostics yet'), findsOneWidget);
      expect(AppDiagnostics.exportText(), isEmpty);
    },
  );

  testWidgets('manual export sends a UTF-8 snapshot to the file picker', (
    tester,
  ) async {
    AppDiagnostics.recordNotification('Lỗi lưu', level: LogLevel.error);
    await tester.pumpWidget(const MaterialApp(home: AppDiagnosticsScreen()));
    final snapshot = AppDiagnostics.exportText();
    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();
    expect(picker.calls, 1);
    expect(picker.fileName, 'diagnostics.txt');
    expect(utf8.decode(picker.bytes!), snapshot);
    expect(appTalker.history.length, 1);
    expect(find.text('Export requested'), findsOneWidget);
  });

  testWidgets('cancelling export does not create a log or success message', (
    tester,
  ) async {
    picker.path = null;
    AppDiagnostics.recordNotification('Safe event', level: LogLevel.warning);
    await tester.pumpWidget(const MaterialApp(home: AppDiagnosticsScreen()));
    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();
    expect(appTalker.history.length, 1);
    expect(find.text('Export requested'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'export failure stays local and never becomes a notification or log',
    (tester) async {
      picker.error = StateError('token=SECRET');
      AppDiagnostics.recordNotification('Safe event', level: LogLevel.warning);
      await tester.pumpWidget(const MaterialApp(home: AppDiagnosticsScreen()));
      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();
      expect(find.text('Export failed. Try again.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(AppDiagnostics.exportText(), isNot(contains('SECRET')));
      expect(appTalker.history.length, 1);
      picker.error = null;
      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();
      expect(find.text('Export requested'), findsOneWidget);
    },
  );

  testWidgets(
    'pending export prevents double saves and safely completes after disposal',
    (tester) async {
      picker.pending = Completer<String?>();
      AppDiagnostics.recordNotification('Safe event', level: LogLevel.error);
      await tester.pumpWidget(const MaterialApp(home: AppDiagnosticsScreen()));
      await tester.tap(find.byIcon(Icons.download));
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.download))
            .onPressed,
        isNull,
      );
      expect(picker.calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      picker.pending!.complete('saved.txt');
      AppDiagnostics.recordNotification(
        'After disposal',
        level: LogLevel.warning,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}

class _ExportPicker extends FilePicker {
  int calls = 0;
  String? fileName;
  Uint8List? bytes;
  String? path = 'saved.txt';
  Object? error;
  Completer<String?>? pending;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    calls++;
    this.fileName = fileName;
    this.bytes = bytes;
    if (error != null) throw error!;
    return pending != null ? pending!.future : path;
  }
}
