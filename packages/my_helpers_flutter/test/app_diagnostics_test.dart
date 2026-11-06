import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_helpers_flutter/my_helpers_flutter.dart';
import 'package:talker/talker.dart' show TalkerObserver, TalkerData;

import 'notification_service_test.dart' as notices;

void main() {
  setUp(() {
    NotificationService.debugResetQueue();
    AppDiagnostics.configure(
      enabled: true,
      notificationLogging: true,
      maxHistoryItems: 200,
      useConsoleLogs: false,
    );
    appTalker.configure(observer: const _QuietObserver());
    AppDiagnostics.clear();
    NotificationService.suppressSnackbars();
  });

  tearDown(() {
    NotificationService.debugResetQueue();
    appTalker.configure(observer: const _QuietObserver());
    AppDiagnostics.configure(
      enabled: true,
      notificationLogging: true,
      maxHistoryItems: 200,
      useConsoleLogs: false,
    );
    AppDiagnostics.clear();
  });

  test(
    'notification defaults log errors, warnings, and developer messages only in debug',
    () {
      showErrorNotification('error');
      showWarningNotification('warning');
      showOkNotification('ok');
      showShortNotification('short');
      showDevNotification('dev');
      expect(appTalker.history.map((entry) => entry.message), [
        'error',
        'warning',
        if (kDebugMode) 'dev',
      ]);
      expect(appTalker.history.map((entry) => entry.logLevel), [
        LogLevel.error,
        LogLevel.warning,
        if (kDebugMode) LogLevel.debug,
      ]);
      expect(appTalker.settings.useConsoleLogs, isFalse);
    },
  );

  test('all helpers and service methods forward per-call privacy controls', () {
    showErrorNotification('secret', log: false);
    showWarningNotification('secret', log: false);
    showDevNotification('secret', log: false);
    showOkNotification('secret', log: false);
    showShortNotification('secret', log: false);
    NotificationService.showError('secret', log: false);
    NotificationService.showWarning('secret', log: false);
    NotificationService.showDev('secret', log: false);
    NotificationService.showOk('secret', log: false);
    NotificationService.showShort('secret', log: false);
    expect(appTalker.history, isEmpty);
    showOkNotification('Safe opt-in', log: true);
    showShortNotification('Safe short opt-in', log: true);
    expect(appTalker.history.map((entry) => entry.logLevel), [
      LogLevel.info,
      LogLevel.info,
    ]);
  });

  testWidgets(
    'safe log message replaces sensitive text without changing display',
    (tester) async {
      await notices.mount(tester);
      showErrorNotification(
        'Sensitive invitation URL',
        logMessage: 'invite.open_failed',
      );
      expect(appTalker.history.single.message, 'invite.open_failed');
      expect(
        AppDiagnostics.exportText(),
        isNot(contains('Sensitive invitation URL')),
      );
      expect(
        (await notices.showAll(tester)).single.text,
        'Sensitive invitation URL',
      );
    },
  );

  testWidgets('each call is logged before grouping and overflow summaries', (
    tester,
  ) async {
    await notices.mount(tester);
    NotificationService.configure(maxQueued: 1);
    showErrorNotification('First detail', groupKey: 'operation');
    showErrorNotification('Second detail', groupKey: 'operation');
    showWarningNotification('Waiting');
    showErrorNotification('Overflow detail');
    expect(appTalker.history.map((entry) => entry.message), [
      'First detail',
      'Second detail',
      'Waiting',
      'Overflow detail',
    ]);
    await notices.showAll(tester);
    expect(appTalker.history.length, 4);
  });

  testWidgets(
    'suppressed errors log individually and flush never re-logs private text',
    (tester) async {
      await notices.mount(tester);
      NotificationService.suppressSnackbars();
      showErrorNotification('Visible but private', log: false);
      NotificationService.flushPendingNotifications();
      await notices.showAll(tester);
      expect(appTalker.history, isEmpty);
      NotificationService.suppressSnackbars();
      showErrorNotification('First');
      showErrorNotification('Second');
      NotificationService.flushPendingNotifications();
      await notices.showAll(tester);
      expect(appTalker.history.map((entry) => entry.message), [
        'First',
        'Second',
      ]);
    },
  );

  test(
    'notification logging and all diagnostics can be disabled independently',
    () {
      AppDiagnostics.configure(notificationLogging: false);
      showErrorNotification('Not logged', log: true);
      AppDiagnostics.recordException(
        Exception('private'),
        StackTrace.empty,
        event: 'save.failed',
      );
      expect(appTalker.history.length, 1);
      AppDiagnostics.configure(enabled: false, notificationLogging: true);
      showWarningNotification('Disabled');
      AppDiagnostics.recordException(
        Exception('private'),
        StackTrace.empty,
        event: 'save.failed',
      );
      expect(appTalker.history.length, 1);
      AppDiagnostics.clear();
      expect(appTalker.history, isEmpty);
    },
  );

  test('history is bounded and shrinking the limit removes oldest records', () {
    for (var i = 0; i < 6; i++) {
      showErrorNotification('Event $i');
    }
    AppDiagnostics.configure(maxHistoryItems: 2);
    expect(appTalker.history.map((entry) => entry.message), [
      'Event 4',
      'Event 5',
    ]);
    showErrorNotification('Event 6');
    expect(appTalker.history.map((entry) => entry.message), [
      'Event 5',
      'Event 6',
    ]);
    expect(
      () => AppDiagnostics.configure(maxHistoryItems: 0),
      throwsArgumentError,
    );
    expect(appTalker.settings.maxHistoryItems, 2);
  });

  test(
    'caught exception never stringifies its payload and omits unsafe stack lines',
    () {
      AppDiagnostics.recordException(
        _SensitiveException(),
        StackTrace.fromString(
          '#0      Saver.save (package:app/saver.dart:12:3)\n'
          '#1      main (dart:async/future.dart:5:2)\n'
          '#2      sign (https://example.com/invite?token=SECRET:1:2)\n'
          '#3      auth (file:///Users/SECRET/passkey.dart:1:2)\n'
          '#4      api (package:app/client.dart?auth=SECRET:1:2)\n'
          'WebAuthn payload SECRET',
        ),
        event: 'invite.sign_failed',
      );
      final text = AppDiagnostics.exportText();
      expect(text, contains('invite.sign_failed (_SensitiveException)'));
      expect(text, contains('package:app/saver.dart:12:3'));
      expect(text, contains('dart:async/future.dart:5:2'));
      expect(text, isNot(contains('SECRET')));
      expect(text, isNot(contains('https://')));
      expect(text, isNot(contains('file:///')));
      expect(appTalker.history.single.logLevel, LogLevel.error);
      expect(
        () => AppDiagnostics.recordException(
          Exception(),
          StackTrace.empty,
          event: 'https://private',
        ),
        throwsArgumentError,
      );
    },
  );

  test('unrecognized browser stacks have a safe fallback', () {
    AppDiagnostics.recordException(
      Exception('secret'),
      StackTrace.fromString('at https://private?token=SECRET'),
      event: 'sign.failed',
    );
    expect(AppDiagnostics.exportText(), contains('[no safe stack frames]'));
    expect(AppDiagnostics.exportText(), isNot(contains('SECRET')));
    expect(AppDiagnostics.exportText(), isNot(contains('secret')));
  });

  test(
    'logger feedback is not recursively logged and logger failures are contained',
    () {
      final observer = _FeedbackObserver();
      appTalker.configure(observer: observer);
      expect(() => showErrorNotification('Original'), returnsNormally);
      expect(observer.calls, 1);
      expect(appTalker.history, isEmpty);
      appTalker.configure(observer: const _QuietObserver());
      showErrorNotification('Recovery');
      expect(appTalker.history.last.message, 'Recovery');
    },
  );
}

class _SensitiveException implements Exception {
  @override
  String toString() =>
      throw StateError('Sensitive payload must not be inspected');
}

class _QuietObserver extends TalkerObserver {
  const _QuietObserver();
}

class _FeedbackObserver extends TalkerObserver {
  int calls = 0;

  @override
  void onLog(TalkerData log) {
    calls++;
    showErrorNotification('Logger internal failure');
    throw StateError('Private diagnostics failure');
  }
}
