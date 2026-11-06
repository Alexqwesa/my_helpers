# Repository guidance

## Scope and structure

This is a personal Dart/Flutter helper workspace used by other projects.
Keep changes focused on the requested behavior and preserve existing public
APIs unless the task requires changing them.

- `packages/my_helpers_dart`: pure Dart helpers shared by server and Flutter
  apps. Keep this package free of Flutter dependencies.
- `packages/my_helpers_flutter`: Flutter widgets, localization, routing,
  Riverpod helpers, file upload UI, and Pluto table integrations.
- `packages/my_helpers_flutter/test`: package widget and behavior tests.
- Root `lib`, `test`, and platform directories contain the Flutter demo
  scaffold; shared helper changes normally belong in the packages.

The root `pubspec.yaml` defines the Pub workspace. It requires Dart
`>=3.10.0 <4.0.0`; the Flutter package requires Flutter `>=3.38.0`.

## Development and validation

Run dependency resolution from the repository root:

```sh
flutter pub get
```

Format only the Dart files you change with `dart format <paths>`. Follow the
existing code style and analyzer configuration; avoid unrelated formatting
or dependency upgrades.

For Flutter helper changes, run these commands from
`packages/my_helpers_flutter`:

```sh
flutter analyze
flutter test
```

For pure Dart helper changes, run `dart analyze` from
`packages/my_helpers_dart`. Run relevant tests when present; this package
currently has no test suite. For a focused Flutter check, use
`flutter test test/app_table_test.dart` or the relevant test file from the
Flutter package directory.

Add or update meaningful behavior tests for bug fixes and new behavior.
Documentation-only changes need link/content review and `git diff --check`.
Report checks that could not run and their reason.

## Package boundaries and exports

Keep feature-specific fetching, backend models, queries, and business actions
in consuming apps. Shared helpers should accept data and callbacks rather
than introduce dependencies on a particular app or server framework.

Expose intended public helpers through the appropriate package entry point:

- `packages/my_helpers_dart/lib/my_helpers_dart.dart`
- `packages/my_helpers_flutter/lib/my_helpers_flutter.dart`
- `packages/my_helpers_flutter/lib/meta_pluto_grid.dart` for table helpers

The Flutter entry point re-exports Dart helpers while supplying its own
`aloc`; preserve that distinction when changing exports.

## AppTable integration

Follow the [AppTable integration rules](packages/my_helpers_flutter/lib/features/meta_pluto_grid/README.md#apptable-integration) and
the [table API documentation](packages/my_helpers_flutter/lib/features/meta_pluto_grid/README.md).

- Sorting is caller-controlled (server-controlled for remote data). For local
  data, sort the full list before paging. Title clicks alternate ascending/descending;
  explicit sort menu commands honor the requested direction.
- Always populate `PlutoColumn.title`, including with `titleSpan`, because
  the column selector uses `title`.
- Avoid duplicate custom and built-in menu/resize icons.
- Preserve row styling through a dedicated row-color callback forwarded by
  adapters. Consult the README for the current API limitation.
- Prefer [search_anchor_picker](https://pub.dev/packages/search_anchor_picker)
  for searchable pickers.

Keep data/query ownership in the consuming feature. New table screens should
use the controlled `AppTable` API; older `TableViewController`/`PlutoBridge`
helpers remain in the feature directory.

## Localization

Follow the [localization warning](README.md#localization-warning).
Prefer Flutter `context.aloc(...)` inside widget builds; it registers a locale
dependency through `Localizations.localeOf(context)`. Plain `aloc(...)` is
available outside widgets and does not register that dependency. Do not remove
an existing `AppLocalizations.of(context)` dependency from widgets using plain
`aloc(...)` without migrating them to the context extension.

When changing `LocaleSwitchWidget`, test compact and wide layouts, including
one configured language with `showAuto` enabled and disabled. Forward Auto
visibility into picker dialogs as well as the main control.

## Notifications

Follow the [notification usage and grouping contract](README.md#notifications).
Implement shared changes in the Flutter package, not the legacy root copies.
Keep exact-text deduplication as the default; use stable, explicit `groupKey`
values for intentional similarity grouping. Include the active notification
in deduplication and guard display after asynchronous frame waits against
cancellation. Preserve flood summaries and severity handling.

For queue changes, cover cancellation before the first frame, duplicates
while visible, distinct errors sharing a prefix, and multilingual grouping.
Run `flutter test test/notification_service_test.dart` and
`flutter test test/locale_switch_widget_test.dart` for the corresponding
features, then the package analysis and full test suite as described above.

## Change hygiene

Check the working tree before editing and preserve unrelated user changes.
Do not edit generated caches or build output. Change manifests and the
workspace lockfile only when needed for the task. Update nearby usage
documentation when public behavior or integration requirements change.
