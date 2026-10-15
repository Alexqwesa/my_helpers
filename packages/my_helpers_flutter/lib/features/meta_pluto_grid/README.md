# Shared server table

`AppTable<T>` is the shared, read-only Pluto table. It has no Serverpod,
Riverpod, or SimOps dependencies. It owns grid styling, localized grid menus,
responsive columns, hidden-column details, row selection, and the pager.

The feature owns its data, loading/error/empty presentation, query, filters,
and actions. Import `package:my_helpers_flutter/meta_pluto_grid.dart` in each consuming app.

```dart
AppTable<Task>(
  columns: const [
    AppTableColumn(key: 'id', title: 'ID', minWidth: 70, fixedWidth: 75),
    AppTableColumn(key: 'title', title: 'Title', minWidth: 260),
    AppTableColumn(key: 'comment', title: 'Comment', minWidth: 260, hidePriority: 900),
  ],
  items: tasks,
  revision: dataAndQueryRevision,
  total: total,
  rowsPerPage: query.size,
  page: query.page,
  height: 500,
  sortField: query.sortField,
  sortAscending: query.sortAscending,
  availableRowsPerPage: const [10, 20, 50],
  cellBuilder: buildTaskCell,
  onSort: (field, {required ascending}) => updateSort(field, ascending: ascending),
  onPageChanged: updatePage,
  onPageSizeChanged: updatePageSize,
  onRowTap: openTask,
  onDetails: showHiddenTaskFields,
)
```

- Pass the actual query sort to the table; it drives the header indicator.
  Fetch globally sorted data in `onSort`, resetting the page to zero.
- `onPageSizeChanged(size, page)` supplies the page retaining the first visible
  row. Update both values together in the feature query.
- Change `revision` when the query or row data changes. The grid also recreates
  when the locale, visible columns, or controlled sort changes.
- Higher `hidePriority` values hide first. At least two columns remain visible;
  very narrow layouts may scroll. `fixedWidth` columns keep their width.
- Optional `header` widgets appear beside the column title, for feature filters.
  Set `sortable: false` for columns without a server sort field.
- Provide `onDetails` to show the info column when responsive columns are hidden.
- Optional `onLoaded` is an escape hatch for feature-specific Pluto listeners;
  the feature must remove those listeners when replacing or disposing the grid.

This directory still contains older `TableViewController`/`PlutoBridge` helpers.
The new `AppTable` manages its own grid; new screens should use its controlled API.
The table is shared through the `my_helpers_flutter` package; feature adapters remain in each app.
