import 'dart:async';
import 'dart:collection';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:my_helpers/features/aloc.dart';

String localizedMsg(String message) {
  // Convert literal "\n" sequences coming from the server
  // into real newlines.
  final normalized = message.replaceAll(r'\n', '\n');

  final pipes = RegExp(r'\|')
      .allMatches(normalized)
      .length;

  if (pipes == 2) {
    try {
      return aloc(normalized); // "en|vi|ru"
    } catch (_) {
      // Fallback if aloc throws for any reason
      return normalized;
    }
  }

  if (pipes == 4) {
    final first = normalized.indexOf('|');
    final last = normalized.lastIndexOf('|');
    if (first != -1 && last != -1 && last > first) {
      final trimmed = normalized.substring(first + 1, last);
      try {
        return aloc(trimmed); // normalized "en|vi|ru"
      } catch (_) {
        return trimmed;
      }
    }
  }

  return normalized;
}

/// Use like this:
///      MaterialApp.router(
///        scaffoldMessengerKey: NotificationService.messengerKey,


enum _NotificationKind {
  ok,
  error,
  warning,
  dev,
  short,
}

class NotificationService {
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static Future<void> _waitForStableFrame() async {
    // Wait until no layout/animation callbacks are running.
    while (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      await WidgetsBinding.instance.endOfFrame;
    }
    // One extra frame to let route/overlay transitions settle.
    await WidgetsBinding.instance.endOfFrame;
  }

  static String _loc(String message) {
    try {
      return localizedMsg(message);
    } catch (_) {
      return message;
    }
  }

  // ───────── Queue + dedupe ─────────

  static final Queue<_QueuedNotification> _queue = Queue<_QueuedNotification>();
  static bool _isDraining = false;
  static bool _suppressNotifications = false;
  static final List<String> _pendingErrors = <String>[];
  static final List<String> _pendingOks = <String>[];
  static final List<String> _pendingWarnings = <String>[];

  static void suppressSnackbars() {
    _suppressNotifications = true;
  }

  static void flushPendingNotifications({bool showOks = false}) {
    _suppressNotifications = false;
    if (_pendingErrors.isNotEmpty) {
      final msg = _pendingErrors.length == 1
          ? _pendingErrors.first
          : '${_pendingErrors.length} errors occurred|'
              '${_pendingErrors.length} lỗi xảy ra|'
              '${_pendingErrors.length} ошибок';
      showError(msg);
    } else if (showOks && _pendingOks.isNotEmpty) {
      final msg = _pendingOks.length == 1
          ? _pendingOks.first
          : '${_pendingOks.length} operations completed|'
              '${_pendingOks.length} thao tác hoàn tất|'
              '${_pendingOks.length} операций завершено';
      showOk(msg);
    }
    _pendingErrors.clear();
    _pendingOks.clear();
    _pendingWarnings.clear();
  }

  static void _enqueueWhileSuppressed(_NotificationKind kind, String message) {
    switch (kind) {
      case _NotificationKind.ok:
      case _NotificationKind.short:
        _pendingOks.add(message);
      case _NotificationKind.warning:
        _pendingWarnings.add(message);
      case _NotificationKind.error:
        _pendingErrors.add(message);
      case _NotificationKind.dev:
        break;
    }
  }

  static void _show(_NotificationKind kind,
      String message, {
        Duration? overrideDuration,
      }) {
    if (_suppressNotifications) {
      _enqueueWhileSuppressed(kind, message);
      return;
    }
    final existing = _queue.firstWhere(
          (q) => q.kind == kind && q.message == message,
      orElse: () => _QueuedNotification.none,
    );

    if (!identical(existing, _QueuedNotification.none)) {
      // Same kind+text already in queue → just bump its repeat count
      existing.repeatCount++;
      existing.overrideDuration = overrideDuration ?? existing.overrideDuration;
    } else {
      _queue.add(
        _QueuedNotification(
          kind: kind,
          message: message,
          repeatCount: 1,
          overrideDuration: overrideDuration,
        ),
      );
    }

    if (!_isDraining) {
      _drainQueue();
    }
  }

  static void _drainQueue() async {
    _isDraining = true;

    while (_queue.isNotEmpty) {
      final item = _queue.removeFirst();

      final style = _styleForKind(item.kind);
      var duration = item.overrideDuration ?? style.defaultDuration;

      // Extend duration based on how many times this exact notification was requested
      if (item.repeatCount > 1) {
        // e.g. base * repeatCount, but clamp to max
        final baseMillis = duration.inMilliseconds;
        final computedMillis = baseMillis * item.repeatCount;
        final clampedMillis = computedMillis.clamp(baseMillis, 4000); // max 4s
        duration = Duration(milliseconds: clampedMillis);
      }

      await _showNow(item.message, style.bgColor, duration);
    }

    _isDraining = false;
  }

  // ───────── Actual display ─────────

  static Future<void> _showNow(String message,
      Color bg,
      Duration duration,) async {
    await _waitForStableFrame();

    final m = messengerKey.currentState;
    if (m == null || !m.mounted) {
      dev.log('NotificationService.messengerKey state is not mounted or key is missed');
      return;
    }

    final snackBar = SnackBar(
      duration: duration,
      backgroundColor: bg,
      content: Row(
        children: [
          Expanded(child: Text(_loc(message))),
          IconButton(
            icon: const Icon(Icons.copy, size: 20, color: Colors.white),
            tooltip: aloc(
              'Copy to clipboard|Sao chép vào bảng tạm|Копировать в буфер обмена',
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Colors.white),
            tooltip: aloc('Close|Đóng|Закрыть'),
            onPressed: () {
              m.clearSnackBars();
            },
          ),
        ],
      ),
    );

    final controller = m.showSnackBar(snackBar);
    // Wait until this snackbar is dismissed before showing next in queue
    await controller.closed;
  }

  // ───────── Style per kind ─────────

  static _NotificationStyle _styleForKind(_NotificationKind kind) {
    switch (kind) {
      case _NotificationKind.ok:
        return _NotificationStyle(
          bgColor: Colors.green,
          defaultDuration: const Duration(milliseconds: 4000),
        );
      case _NotificationKind.error:
        return _NotificationStyle(
          bgColor: Colors.red,
          defaultDuration: const Duration(milliseconds: 4000),
        );
      case _NotificationKind.warning:
        return _NotificationStyle(
          bgColor: Colors.yellow.shade800,
          defaultDuration: const Duration(milliseconds: 4000),
        );
      case _NotificationKind.dev:
        return _NotificationStyle(
          bgColor: Colors.purple.shade500,
          defaultDuration: const Duration(milliseconds: 4000),
        );
      case _NotificationKind.short:
        return _NotificationStyle(
          bgColor: Colors.grey.shade500,
          defaultDuration: const Duration(milliseconds: 300),
        );
    }
  }

  // ───────── Public helpers (unchanged API) ─────────


  static void showOk(String message, {
    Duration? duration,
  }) =>
      _show(
        _NotificationKind.ok,
        message,
        overrideDuration: duration,
      );

  static void showError(String message, {
    Duration? duration,
  }) =>
      _show(
        _NotificationKind.error,
        message,
        overrideDuration: duration,
      );

  static void showWarning(String message, {
    Duration? duration,
  }) =>
      _show(
        _NotificationKind.warning,
        message,
        overrideDuration: duration,
      );

  static void showDev(String message, {
    Duration? duration,
  }) =>
      _show(
        _NotificationKind.dev,
        message,
        overrideDuration: duration,
      );

  static void showShort(String message, {
    Duration? duration,
  }) =>
      _show(
        _NotificationKind.short,
        message,
        overrideDuration: duration,
      );
}

class _NotificationStyle {
  final Color bgColor;
  final Duration defaultDuration;

  const _NotificationStyle({
    required this.bgColor,
    required this.defaultDuration,
  });
}

class _QueuedNotification {
  _QueuedNotification({
    required this.kind,
    required this.message,
    required this.repeatCount,
    this.overrideDuration,
  });

  final _NotificationKind kind;
  final String message;
  int repeatCount;
  Duration? overrideDuration;

  static final none = _QueuedNotification(
    kind: _NotificationKind.ok,
    message: '__none__',
    repeatCount: 0,
  );
}

// Convenience functions (unchanged)


void showErrorNotification(String message, {
  Duration? duration,
}) {
  NotificationService.showError(message, duration: duration);
}

void showDevNotification(String message, {
  Duration? duration,
}) {
  NotificationService.showDev(message, duration: duration);
}

void showShortNotification(String message, {
  Duration? duration,
}) {
  NotificationService.showShort(message, duration: duration);
}

void showOkNotification(String message, {
  Duration? duration,
}) {
  NotificationService.showOk(message, duration: duration);
}

void showWarningNotification(String message, {
  Duration? duration,
}) {
  NotificationService.showWarning(message, duration: duration);
}