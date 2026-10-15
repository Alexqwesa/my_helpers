# my_helpers

Personal helper code used across my own projects.

This repository is public only so my projects and CI can access it easily.
It is task-specific, undocumented, unstable, and not intended as a reusable
library for others.

## Localization warning

`aloc(...)` currently depends on `AppLocalizations.of(context);` being called in the widget build path so Flutter registers the localization dependency. Without that call, text using `aloc(...)` may not switch language on the fly.

TODO: add and migrate to `context.aloc(...)` instead of plain `aloc(...)`, so widgets no longer need a separate `AppLocalizations.of(context);` call just to react to language changes.