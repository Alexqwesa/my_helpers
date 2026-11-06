# my_helpers

Personal helper code used across my own projects.

This repository is public only so my projects and CI can access it easily.
It is task-specific, undocumented, unstable, and not intended as a reusable
library for others.

## AppTable

See the [AppTable API and integration rules](packages/my_helpers_flutter/lib/features/meta_pluto_grid/README.md) for local and server-backed tables.

## Notifications

Use the notification helpers exported by `my_helpers_flutter` and set
`MaterialApp.scaffoldMessengerKey` (or the router equivalent) to
`NotificationService.messengerKey`.

```dart
showErrorNotification('Could not save the record');
showErrorNotification('Upload failed for item 42', groupKey: 'batch-upload');
NotificationService.configure(maxQueued: 5);
NotificationService.discardQueue(dismissCurrent: true);
```

- By default, only identical text of the same severity/kind is deduplicated.
  This includes the active notification, even before its first visible frame.
- Notifications display oldest first (FIFO): calls for A, B, then C display
  A → B → C. New arrivals wait behind existing entries regardless of severity.
  This is notification-call order, not the start order of async operations;
  operations finishing in reverse order can enqueue their results in reverse.
  Grouped repeats update the original entry without moving it, and overflow
  summaries replace messages beyond the queue limit.
- Pass an optional stable `groupKey` to intentionally combine different texts
  of the same kind. Use the same key across translations. The first message
  stays visible with a live `+N similar` suffix for differing messages. Exact
  repeats do not add a suffix. Keys are scoped to the active/waiting lifetime,
  not a permanent history. Keep distinct failures separate when details matter.
- All five helpers (`showErrorNotification`, `showWarningNotification`,
  `showOkNotification`, `showDevNotification`, `showShortNotification`) and
  their `NotificationService.show*` methods accept `duration`, `groupKey`,
  `log`, and `logMessage` (see diagnostics configuration below).
  A repeat does not restart an already displayed notification's timeout.
- Up to five distinct notifications wait by default, in addition to the active
  one. Further arrivals become a count summary using the highest severity
  among them. Automatic diagnostic logging records individual error/warning
  calls before grouping or overflow, subject to the diagnostics history limit.
  Review or omit sensitive details rather than logging raw errors.
- `configure(similarPrefixLength: n)` explicitly enables legacy prefix
  grouping. It compares the source-language segment for `en|vi|ru` messages,
  not a prefix spanning translations. `0` groups all unkeyed messages of a kind.
  Prefer explicit keys; prefix grouping can hide different errors. Explicit
  keys take precedence. Omitted configuration values retain their settings.
- `discardQueue()` clears waiting notifications and overflow summaries while
  allowing the active notification to finish. With `dismissCurrent: true`, it
  also cancels an active notification awaiting a stable frame or dismisses
  one already visible. New notifications can be shown afterward.
- `suppressSnackbars()` collects messages separately. Queue discarding does
  not clear those collections. `flushPendingNotifications()` prioritizes an
  error summary; `showOks: true` allows an OK summary when there are no errors.
  Warnings are cleared by the flush, and grouping keys are not retained during
  suppression.

## Diagnostics with Talker

The Flutter package exports one shared `appTalker`, `AppDiagnostics`, and
`AppDiagnosticsScreen` through `package:my_helpers_flutter/my_helpers_flutter.dart`.
It uses [Talker](https://pub.dev/packages/talker) core with the existing file
picker for export; no HTTP/Riverpod logger, route observer, global exception
hook, network transport, or persistent log store is installed.

Configure once at startup; no separate initialization is required:

```dart
import 'package:my_helpers_flutter/my_helpers_flutter.dart';

// These are the defaults. Omitted configuration values retain their settings.
AppDiagnostics.configure(
  enabled: true,
  notificationLogging: true,
  maxHistoryItems: 200,
  useConsoleLogs: false,
);
```

| Event | Default logging |
| --- | --- |
| Error notification | Error |
| Warning notification | Warning |
| OK or short notification | None |
| Developer notification | Debug level in debug builds only |
| Explicit caught exception via `AppDiagnostics.recordException` | Error, with filtered stack frames |
| Riverpod state changes | None |
| HTTP requests/responses | None |

All notification helpers and `NotificationService.show*` methods accept these
per-call controls:

```dart
// Display this text without logging it anywhere in Talker.
showErrorNotification('Private details for the user', log: false);

// Display detailed text, but log only an approved stable event name.
showWarningNotification(
  'Detailed message for the user',
  logMessage: 'invite.validation_failed',
);

// Optional explicit logging for normally quiet OK/short calls.
showOkNotification('Completed', log: true, logMessage: 'batch.completed');
```

`log: null` follows the defaults; `false` excludes that call entirely; `true`
explicitly opts in, including developer notifications outside debug builds.
`logMessage` replaces the logged message without changing the displayed text;
it does not opt quiet notification kinds into logging. `log: false` always wins.
`notificationLogging: false` disables notification logging globally, including
per-call opt-ins. `enabled: false` disables all Talker recording. Existing
history remains until `AppDiagnostics.clear()`; clear it on logout or when
diagnostic consent is withdrawn if appropriate for the consuming app.

Each opted-in notification call is logged once, before UI deduplication,
overflow, or suppression. Flushing suppressed messages does not log them a
second time and cannot undo a per-call privacy opt-out.

For an explicitly caught exception, choose a safe event name:

```dart
try {
  // Perform the operation.
} catch (error, stackTrace) {
  AppDiagnostics.recordException(error, stackTrace, event: 'invite.sign_failed');
  showErrorNotification('Signing failed', log: false); // Avoid a duplicate log.
}
```

`recordException` records the event and exception type without calling the
exception's `toString()` or retaining its payload. Event identifiers must match
`[a-z][a-z0-9_.-]{0,79}`. Only recognized Dart/package stack frames are retained,
up to 40; browser frames, URLs, query strings, local file paths, and unknown
lines are omitted. Browser-only stacks may therefore have no usable frames.
This conservative filter is not a general-purpose secret detector: review
event names, source identifiers, and any manually logged text yourself.

To review and export the memory history, explicitly open the screen:

```dart
Navigator.of(context).push(MaterialPageRoute<void>(
  builder: (_) => const AppDiagnosticsScreen(),
));
```

The screen shows oldest entries first, offers Clear history, and exports a
UTF-8 `diagnostics.txt` snapshot only when the user presses Export. It uses a
save dialog on desktop, the platform file picker on mobile, and a browser
download on web. macOS requires the file picker's user-selected-file read/write
entitlement. Export errors are shown locally without logging or showing a
notification. Logging failures are contained, with a guard against synchronous
logger-to-notification feedback. Do not wire Talker observers or stream
listeners back into notification logging; use `log: false` for diagnostics UI
notifications in consuming apps.

History is bounded by entry count and lives only in memory. Reloading the
browser or restarting the process loses it unless the user exported it.
`AppDiagnostics.exportText()` returns a snapshot for a custom manual export
flow; it does not save or send anything. Configure a smaller limit to reduce
retention. Do not add persistence or broad instrumentation by default.

For SIMOPS and external passkey signing, **never log full invitation URLs,
authentication tokens, WebAuthn payloads, signing responses, or complete SIMOPS
documents**. Prefer chosen event names and non-sensitive metadata. Review
exception messages before any direct `appTalker` call; direct Talker calls
bypass the notification privacy controls and safe exception wrapper. Manual
exports contain the recorded text, so review them before sharing.

## Localization warning

In Flutter widgets, use `context.aloc('English|Tiếng Việt|Русский')` from
`my_helpers_flutter`. It reads `Localizations.localeOf(context)`, registering
the dependency so text rebuilds when the locale changes. Plain `aloc(...)`
remains available outside widgets, but does not register that dependency.
Widgets still using plain `aloc(...)` need a localization dependency in their
build path, such as `AppLocalizations.of(context)`.

`LocaleSwitchWidget(showAuto: true)` adds the system/browser language option
alongside configured languages, including a single configured language.
At widths below 600 logical pixels it uses a compact picker; Auto is included
in that dialog only when `showAuto` is true. With `showAuto: false` (the default),
Auto is omitted from both the wide toggle and picker dialogs. Selecting Auto
uses `LocaleSwitcher`'s `system` entry and its normal persistence setup.
The configured language list comes from `langsForSwitcherProvider`; the compact
dialog lists the app's supported locales.
