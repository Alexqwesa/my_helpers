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
- Pass an optional stable `groupKey` to intentionally combine different texts
  of the same kind. Use the same key across translations. The first message
  stays visible with a live `+N similar` suffix for differing messages. Exact
  repeats do not add a suffix. Keys are scoped to the active/waiting lifetime,
  not a permanent history. Keep distinct failures separate when details matter.
- All five helpers (`showErrorNotification`, `showWarningNotification`,
  `showOkNotification`, `showDevNotification`, `showShortNotification`) and
  their `NotificationService.show*` methods accept `duration` and `groupKey`.
  A repeat does not restart an already displayed notification's timeout.
- Up to five distinct notifications wait by default, in addition to the active
  one. Further arrivals become a count summary using the highest severity
  among them. This UI summary is not a diagnostic log; log full errors in the
  consuming app when needed.
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
