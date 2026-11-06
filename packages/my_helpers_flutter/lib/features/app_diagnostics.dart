import 'package:talker/talker.dart';

export 'package:talker/talker.dart' show Talker, TalkerSettings, LogLevel;

/// The shared, bounded, memory-only diagnostics history. No automatic console
/// output, persistence, HTTP interception, or state observers are installed.
final appTalker = Talker(
  settings: TalkerSettings(maxHistoryItems: 200, useConsoleLogs: false),
);

class AppDiagnostics {
  AppDiagnostics._();

  static bool _notificationLogging = true;
  static bool _writing = false;

  /// Call at startup. Omitted settings retain their current values.
  /// Disabling logging does not erase history; use [clear] when needed.
  static void configure({
    bool? enabled,
    bool? notificationLogging,
    int? maxHistoryItems,
    bool? useConsoleLogs,
  }) {
    if (maxHistoryItems != null && maxHistoryItems < 1) {
      throw ArgumentError.value(
        maxHistoryItems,
        'maxHistoryItems',
        'must be positive',
      );
    }
    appTalker.configure(
      settings: appTalker.settings.copyWith(
        enabled: enabled,
        maxHistoryItems: maxHistoryItems,
        useConsoleLogs: useConsoleLogs,
      ),
    );
    final limit = appTalker.settings.maxHistoryItems;
    if (appTalker.history.length > limit) {
      appTalker.history.removeRange(0, appTalker.history.length - limit);
    }
    _notificationLogging = notificationLogging ?? _notificationLogging;
  }

  /// Receives only messages the caller has approved for logging. Called before
  /// notification grouping/suppression so details are not lost in UI summaries.
  static void recordNotification(String message, {required LogLevel level}) {
    if (!_notificationLogging) return;
    _write(() => appTalker.log(message, logLevel: level));
  }

  /// Logs an explicit caught exception without calling its toString().
  /// [event] must be a chosen, non-sensitive identifier, e.g. `invite.sign_failed`.
  /// Only package/Dart stack frames are retained; URLs, query strings, local
  /// file paths, browser frames and unrecognized lines are omitted entirely.
  static void recordException(
    Object exception,
    StackTrace stackTrace, {
    required String event,
  }) {
    if (!RegExp(r'^[a-z][a-z0-9_.-]{0,79}$').hasMatch(event)) {
      throw ArgumentError(
        'event must be a non-sensitive lowercase event identifier',
      );
    }
    _write(() {
      final safeFrames = stackTrace
          .toString()
          .split('\n')
          .where(
            (line) => RegExp(
              r'^#\d+\s+[a-zA-Z0-9_.$<>]+\s+\((?:package:[a-zA-Z0-9_./-]+\.dart|dart:[a-zA-Z0-9_./-]+)(?::\d+){0,2}\)\s*$',
            ).hasMatch(line),
          )
          .take(40)
          .join('\n');
      appTalker.error(
        '$event (${exception.runtimeType})',
        null,
        StackTrace.fromString(
          safeFrames.isEmpty ? '[no safe stack frames]' : safeFrames,
        ),
      );
    });
  }

  static void _write(void Function() write) {
    if (_writing) return;
    _writing = true;
    try {
      write();
    } catch (_) {
      // A logger failure must never trigger another log or a notification.
    } finally {
      _writing = false;
    }
  }

  // Talker's cleanHistory is a no-op while disabled. Explicit user clearing
  // must still erase previously collected records when logging is off.
  static void clear() => appTalker.history.clear();

  /// A manual snapshot. Nothing is saved or transmitted by this method.
  static String exportText() => appTalker.history
      .map(
        (entry) =>
            '${entry.time.toUtc().toIso8601String()} ${entry.generateTextMessage()}',
      )
      .join('\n\n');
}
