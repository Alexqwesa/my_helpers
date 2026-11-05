import 'dart:async';
import 'dart:collection';
import 'dart:developer' as dev;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:my_helpers_flutter/features/aloc.dart';

String localizedMsg(String message) {
  // Convert literal "\n" sequences coming from the server
  // into real newlines.
  final normalized = message.replaceAll(r'\n', '\n');

  final pipes = RegExp(r'\|').allMatches(normalized).length;

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

enum _NotificationKind { ok, error, warning, dev, short }

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

  static String _locFromContext(BuildContext context, String message) {
    final normalized = message.replaceAll(r'\n', '\n');
    final pipes = RegExp(r'\|').allMatches(normalized).length;

    try {
      if (pipes == 2) {
        return context.aloc(normalized);
      }

      if (pipes == 4) {
        final first = normalized.indexOf('|');
        final last = normalized.lastIndexOf('|');
        if (first != -1 && last != -1 && last > first) {
          return context.aloc(normalized.substring(first + 1, last));
        }
      }
    } catch (_) {
      return _loc(message);
    }

    return normalized;
  }

  // ───────── Queue + dedupe ─────────

  static final Queue<_QueuedNotification> _queue = Queue<_QueuedNotification>();
  static bool _isDraining = false;
  static int _drainGeneration = 0;
  static bool _suppressNotifications = false;
  static final List<String> _pendingErrors = <String>[];
  static final List<String> _pendingOks = <String>[];
  static final List<String> _pendingWarnings = <String>[];

  static const defaultMaxQueued = 5;
  static const defaultSimilarPrefixLength = 30;

  static int _maxQueued = defaultMaxQueued;
  static int _similarPrefixLength = defaultSimilarPrefixLength;

  /// At most this many different notifications wait in the queue. Anything
  /// beyond that is folded into a single "more notifications" entry placed
  /// after them, so a flood cannot keep the user reading toasts for minutes.
  static int get maxQueued => _maxQueued;

  /// Notifications of the same kind whose texts start with the same this-many
  /// characters are treated as one: ids, counters and exception details
  /// normally come after that prefix. The first text is shown, followed by a
  /// "+N similar" line. Texts no longer than this must match completely.
  static int get similarPrefixLength => _similarPrefixLength;

  /// Changes the flood-protection limits; omitted arguments keep their value.
  /// Call it once at start-up, e.g. in `main()`.
  ///
  /// [maxQueued] must be at least 1. [similarPrefixLength] must not be
  /// negative; pass a large number to merge only identical texts, or 0 to merge
  /// everything of the same kind. Notifications that are already waiting keep
  /// their place; the new limits apply to what arrives afterwards.
  static void configure({int? maxQueued, int? similarPrefixLength}) {
    if (maxQueued != null && maxQueued < 1) {
      throw ArgumentError.value(maxQueued, 'maxQueued', 'must be at least 1');
    }
    if (similarPrefixLength != null && similarPrefixLength < 0) {
      throw ArgumentError.value(
        similarPrefixLength,
        'similarPrefixLength',
        'must not be negative',
      );
    }
    _maxQueued = maxQueued ?? _maxQueued;
    _similarPrefixLength = similarPrefixLength ?? _similarPrefixLength;
  }

  /// Drops every notification that is still waiting, including the "more
  /// notifications" summary. A notification already taken from the queue
  /// finishes normally, unless [dismissCurrent] is true and it is visible.
  /// Notifications collected by [suppressSnackbars] are not touched.
  static void discardQueue({bool dismissCurrent = false}) {
    _queue.clear();
    _overflow = null;
    if (dismissCurrent) messengerKey.currentState?.clearSnackBars();
  }

  /// Shown at least this long: it summarises several notifications.
  static const _overflowMinDuration = Duration(seconds: 3);

  /// The "more notifications" entry while it waits at the end of [_queue].
  static _QueuedNotification? _overflow;

  static String _groupKey(_NotificationKind kind, String message) {
    final text = message.trim();
    final prefix = text.length <= _similarPrefixLength
        ? text
        : text.substring(0, _similarPrefixLength);
    return '${kind.name}\u0000$prefix';
  }

  static int _severity(_NotificationKind kind) => switch (kind) {
    _NotificationKind.short => 0,
    _NotificationKind.ok => 1,
    _NotificationKind.dev => 2,
    _NotificationKind.warning => 3,
    _NotificationKind.error => 4,
  };

  static String _overflowMessage(int count) =>
      'More notifications: $count|'
      'Thêm thông báo: $count|'
      'Ещё уведомлений: $count';

  static String _similarSuffix(int count) =>
      '+$count similar|+$count tương tự|+$count похожих';

  static void _addToOverflow(_NotificationKind kind) {
    final overflow = _overflow;
    if (overflow == null) {
      final created = _QueuedNotification(
        kind: kind,
        message: '',
        repeatCount: 1,
        isOverflow: true,
      );
      _overflow = created;
      _queue.add(created);
      return;
    }
    overflow.repeatCount++;
    // Keep the most severe colour of everything folded into it.
    if (_severity(kind) > _severity(overflow.kind)) overflow.kind = kind;
  }

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

  static void _show(
    _NotificationKind kind,
    String message, {
    Duration? overrideDuration,
  }) {
    if (_suppressNotifications) {
      _enqueueWhileSuppressed(kind, message);
      return;
    }
    final key = _groupKey(kind, message);
    final existing = _queue.firstWhere(
      (q) => !q.isOverflow && _groupKey(q.kind, q.message) == key,
      orElse: () => _QueuedNotification.none,
    );

    if (!identical(existing, _QueuedNotification.none)) {
      // Same kind and same start of the text already waiting → count it there
      existing.repeatCount++;
      if (existing.message != message) existing.similarCount++;
      existing.overrideDuration = overrideDuration ?? existing.overrideDuration;
    } else if (_overflow != null || _queue.length >= _maxQueued) {
      // Queue is full: everything new goes into the one "more" entry.
      _addToOverflow(kind);
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

  /// Drops anything still queued. Used so a failed test cannot block the next one.
  @visibleForTesting
  static void debugResetQueue() {
    _drainGeneration++;
    _queue.clear();
    _overflow = null;
    _maxQueued = defaultMaxQueued;
    _similarPrefixLength = defaultSimilarPrefixLength;
    _isDraining = false;
    _suppressNotifications = false;
    _pendingErrors.clear();
    _pendingOks.clear();
    _pendingWarnings.clear();
  }

  static Future<void> _drainQueue() async {
    final generation = _drainGeneration;
    _isDraining = true;

    const maxRepeatedDuration = Duration(seconds: 4);

    while (_queue.isNotEmpty && generation == _drainGeneration) {
      final item = _queue.removeFirst();
      if (identical(item, _overflow)) _overflow = null;

      final style = _styleForKind(item.kind);
      var duration = item.overrideDuration ?? style.defaultDuration;

      if (item.isOverflow) {
        if (duration < _overflowMinDuration) duration = _overflowMinDuration;
      } else if (item.repeatCount > 1 && duration < maxRepeatedDuration) {
        // Extend duration based on how many times this notification was requested.
        // If the base duration is already longer than the repeat max, keep the base duration.
        final repeatedMillis = duration.inMilliseconds * item.repeatCount;
        final maxMillis = maxRepeatedDuration.inMilliseconds;

        duration = Duration(milliseconds: math.min(repeatedMillis, maxMillis));
      }

      await _showNow(
        item.isOverflow ? _overflowMessage(item.repeatCount) : item.message,
        style.bgColor,
        duration,
        suffix: item.similarCount > 0 ? _similarSuffix(item.similarCount) : null,
      );
    }

    if (generation == _drainGeneration) _isDraining = false;
  }

  // ───────── Actual display ─────────

  static Future<void> _showNow(
    String message,
    Color bg,
    Duration duration, {
    String? suffix,
  }) async {
    await _waitForStableFrame();

    final m = messengerKey.currentState;
    if (m == null || !m.mounted) {
      dev.log(
        'NotificationService.messengerKey state is not mounted or key is missed',
      );
      return;
    }

    final snackBar = SnackBar(
      duration: duration,
      backgroundColor: bg,
      // Vertical space is owned by [_NotificationMessage] so the height cap
      // includes it. Horizontal padding matches a fixed SnackBar.
      padding: const EdgeInsets.symmetric(horizontal: 24),
      dismissDirection: DismissDirection.down,
      content: _NotificationMessage(
        message: message,
        suffix: suffix,
        onCopy: () => Clipboard.setData(ClipboardData(text: message)),
        onClose: m.clearSnackBars,
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

  static void showOk(String message, {Duration? duration}) =>
      _show(_NotificationKind.ok, message, overrideDuration: duration);

  static void showError(String message, {Duration? duration}) =>
      _show(_NotificationKind.error, message, overrideDuration: duration);

  static void showWarning(String message, {Duration? duration}) =>
      _show(_NotificationKind.warning, message, overrideDuration: duration);

  static void showDev(String message, {Duration? duration}) =>
      _show(_NotificationKind.dev, message, overrideDuration: duration);

  static void showShort(String message, {Duration? duration}) =>
      _show(_NotificationKind.short, message, overrideDuration: duration);
}

/// Largest fraction of the available screen a notification may cover.
const _maxScreenFraction = 0.9;

/// Show the drag-to-hide handle once the notification covers this much of the screen.
const _dragHandleScreenFraction = 0.3;

const _contentVerticalPadding = 14.0;

/// Screen metrics from the view itself. [SnackBar] wraps its content in a
/// [SafeArea], which clears both padding and view padding before this widget
/// builds, so [MediaQuery] here cannot see the inset that still adds height.
_NoticeBounds _noticeBoundsOf(BuildContext context) {
  final raw = MediaQueryData.fromView(View.of(context));
  final keyboard = raw.viewInsets.bottom;
  return _NoticeBounds(
    screenHeight: raw.size.height,
    keyboardInset: keyboard,
    safeAreaBelow: math.max(0.0, raw.viewPadding.bottom - keyboard),
  );
}

class _NoticeBounds {
  const _NoticeBounds({
    required this.screenHeight,
    required this.keyboardInset,
    required this.safeAreaBelow,
  });

  final double screenHeight;
  final double keyboardInset;
  final double safeAreaBelow;

  /// Height of the snackbar body, excluding the safe-area padding below it.
  double get maxBodyHeight {
    final aboveKeyboard = math.max(0.0, screenHeight - keyboardInset);
    final visibleCap = aboveKeyboard * _maxScreenFraction;
    return math.max(0.0, visibleCap - safeAreaBelow);
  }
}

class _NotificationMessage extends StatefulWidget {
  const _NotificationMessage({
    required this.message,
    required this.onCopy,
    required this.onClose,
    this.suffix,
  });

  final String message;

  /// Extra line shown under [message], e.g. "+3 similar" ("en|vi|ru" format).
  final String? suffix;
  final VoidCallback onCopy;
  final VoidCallback onClose;

  @override
  State<_NotificationMessage> createState() => _NotificationMessageState();
}

class _NotificationMessageState extends State<_NotificationMessage> {
  final _bodyKey = GlobalKey();
  final _textKey = GlobalKey();
  bool _showHandle = false;
  bool _measured = false;
  int _measureAttempts = 0;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted || _measured) return;
    final box = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    final textContext = _textKey.currentContext;
    final scrollable = textContext == null
        ? null
        : Scrollable.maybeOf(textContext);
    final position = scrollable?.position;
    if (box == null ||
        !box.hasSize ||
        position == null ||
        !position.hasContentDimensions) {
      if (_measureAttempts++ < 5) _scheduleMeasure();
      return;
    }

    _measured = true;
    final bounds = _noticeBoundsOf(context);
    if (bounds.screenHeight <= 0) return;

    final occupied = box.size.height + bounds.safeAreaBelow;
    // Scrolling text can't also drag the snackbar away, so keep a handle then too.
    final scrolls = position.maxScrollExtent > 1;
    final show =
        occupied >= bounds.screenHeight * _dragHandleScreenFraction || scrolls;
    if (show) setState(() => _showHandle = true);
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _noticeBoundsOf(context);
    final maxContent = bounds.maxBodyHeight;
    final handleExtent = _showHandle ? _DragHideIndicator.extent : 0.0;
    final bodyMax = math.max(0.0, maxContent - handleExtent);
    final suffix = widget.suffix;
    final display =
        NotificationService._locFromContext(context, widget.message) +
        (suffix == null ? '' : '\n${context.aloc(suffix)}');

    return ClipRect(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxContent),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showHandle)
              _DragHideIndicator(
                label: context.aloc(
                  'Drag down to hide|Kéo xuống để ẩn|Потяните вниз, чтобы скрыть',
                ),
              ),
            ConstrainedBox(
              key: _bodyKey,
              constraints: BoxConstraints(maxHeight: bodyMax),
              child: Padding(
                padding: EdgeInsets.only(
                  top: _showHandle ? 0 : _contentVerticalPadding,
                  bottom: _contentVerticalPadding,
                ),
                child: Row(
                  crossAxisAlignment: _showHandle
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        primary: false,
                        child: SelectableText(display, key: _textKey),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        size: 20,
                        color: Colors.white,
                      ),
                      tooltip: context.aloc(
                        'Copy to clipboard|Sao chép vào bảng tạm|Копировать в буфер обмена',
                      ),
                      onPressed: widget.onCopy,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.white,
                      ),
                      tooltip: context.aloc('Close|Đóng|Закрыть'),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DragHideIndicator extends StatelessWidget {
  const _DragHideIndicator({required this.label});

  static const extent = 28.0;
  static const indicatorKey = Key('notification-drag-hide');

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: const SizedBox(
        key: indicatorKey,
        height: extent,
        width: double.infinity,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xE6FFFFFF),
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
            child: SizedBox(width: 36, height: 4),
          ),
        ),
      ),
    );
  }
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
    this.isOverflow = false,
  });

  /// Not final for the overflow entry, which takes the most severe kind folded in.
  _NotificationKind kind;
  final String message;

  /// Times this was requested; for the overflow entry, how many were folded in.
  int repeatCount;

  /// Other texts merged into this one because they start the same way.
  int similarCount = 0;
  Duration? overrideDuration;

  /// The single "more notifications" entry at the end of the queue.
  final bool isOverflow;

  static final none = _QueuedNotification(
    kind: _NotificationKind.ok,
    message: '__none__',
    repeatCount: 0,
  );
}

// Convenience functions (unchanged)

void showErrorNotification(String message, {Duration? duration}) {
  NotificationService.showError(message, duration: duration);
}

void showDevNotification(String message, {Duration? duration}) {
  NotificationService.showDev(message, duration: duration);
}

void showShortNotification(String message, {Duration? duration}) {
  NotificationService.showShort(message, duration: duration);
}

void showOkNotification(String message, {Duration? duration}) {
  NotificationService.showOk(message, duration: duration);
}

void showWarningNotification(String message, {Duration? duration}) {
  NotificationService.showWarning(message, duration: duration);
}
