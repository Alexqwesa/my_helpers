import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:my_helpers/features/aloc.dart';

String localizedMsg(String message) {
  final pipes = RegExp(r'\|').allMatches(message).length;
  if (pipes == 2) {
    try {
      return aloc(message); // "en|vi|ru"
    } catch (_) {
      // Fallback if aloc throws for any reason
      return message;
    }
  }
  if (pipes == 4) {
    final first = message.indexOf('|');
    final last = message.lastIndexOf('|');
    if (first != -1 && last != -1 && last > first) {
      final trimmed = message.substring(first + 1, last);
      try {
        return aloc(trimmed); // normalized "en|vi|ru"
      } catch (_) {
        return trimmed;
      }
    }
  }
  return message;
}

/// Use like this:
///      MaterialApp.router(
///        scaffoldMessengerKey: NotificationService.messengerKey,

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
      return aloc(message);
    } catch (_) {
      return message;
    }
  }

  static Future<void> _show(String message, Color bg) async {
    await _waitForStableFrame(); // ← key part

    final m = messengerKey.currentState;
    if (m == null || !m.mounted) {
      dev.log('NotificationService.messengerKey state is not mounted or key is missed');
      return;
    }

    final snackBar = SnackBar(
      backgroundColor: bg,
      // behavior: SnackBarBehavior.floating,
      content: Row(
        children: [
          Expanded(child: Text(_loc(message))),
          IconButton(
            icon: const Icon(Icons.copy, size: 20, color: Colors.white),
            tooltip: aloc('Copy to clipboard|Sao chép vào bảng tạm|Копировать в буфер обмена'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              // Optional: no nested snackbar here to avoid re-entrancy
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Colors.white),
            tooltip: aloc("Close|Đóng|Закрыть"),
            onPressed: () {
              m.clearSnackBars();
              // Optional: no nested snackbar here to avoid re-entrancy
            },
          ),
        ],
      ),
    );

    // Clear any animating snackbars to avoid status-listener churn.
    // m.clearSnackBars();
    m.showSnackBar(snackBar);
  }

  static void showOk(String message) => _show(message, Colors.green);

  static void showError(String message) => _show(message, Colors.red);

  static void showWarning(String message) => _show(message, Colors.yellow.shade800);

  static void showDev(String message) => _show(message, Colors.purple.shade500);
}

void showErrorNotification(String message) {
  return NotificationService.showError(message);
}

void showDevNotification(String message) {
  return NotificationService.showDev(message);
}

void showOkNotification(String message) => NotificationService.showOk(message);

void showWarningNotification(String message) => NotificationService.showWarning(message);
