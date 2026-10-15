# Shared AppTable

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
  Sort or fetch the full dataset in `onSort`, resetting the page to zero.
- `onPageSizeChanged(size, page)` supplies the page retaining the first visible
  row. Update both values together in the feature query.
- Change `revision` when the query or row data changes. The grid also recreates
  when the locale, visible columns, or controlled sort changes.
- Higher `hidePriority` values hide first. At least two columns remain visible;
  very narrow layouts may scroll. `fixedWidth` columns keep their width.
- Optional `header` widgets appear beside the column title, for feature filters.
  Set `sortable: false` for columns without a supported sort field.
- Provide `onDetails` to show the info column when responsive columns are hidden.
- Optional `onLoaded` is an escape hatch for feature-specific Pluto listeners;
  the feature must remove those listeners when replacing or disposing the grid.

This directory still contains older `TableViewController`/`PlutoBridge` helpers.
The new `AppTable` manages its own grid; new screens should use its controlled API.
The table is shared through the `my_helpers_flutter` package; feature adapters remain in each app.

## Local data

`AppTable` also works with in-memory data; it does not fetch from a server.
Sorting and paging are always controlled by the caller. It renders every
item supplied in `items` without automatically sorting or slicing the list.

For a local dataset:

- Filter and sort a copy of the full list before taking the page slice.
- Set `total` to the filtered list length and pass only the current page in
  `items`, for example `sortedItems.skip(page * rowsPerPage).take(rowsPerPage).toList()`.
- In `onSort`, update `sortField` and `sortAscending`, reset `page` to zero,
  and rebuild with the newly sorted page.
- In `onPageChanged` and `onPageSizeChanged`, update the paging state and
  rebuild the slice. The page-size callback provides both the size and page.
- Change `revision` when the local data or query changes. Clamp or reset the
  page when filtering or removing items makes the current page invalid.

For a single page, pass all items, use `page: 0`, and choose a positive
`rowsPerPage` that fits the list (also included in `availableRowsPerPage`).
The pager remains visible. Set `sortable: false` on columns if local sorting
is not implemented. No separate local-data mode is required.

## AppTable integration

Use `AppTable<T>` for shared, read-only tables with caller-controlled sorting
and paging. The usage example above shows the controlled API. Integrations and changes
to the shared table must follow these rules:

- **Sorting:** The caller owns the sort order (the server for remote data). Pass the active query through
  `sortField` and `sortAscending`, and sort or fetch the full dataset in `onSort`
  rather than sorting only the current page. Reset the page to zero when the
  sort changes. Repeated title clicks must alternate ascending/descending;
  do not introduce a third, unsorted state. Explicit menu commands such as
  “Sort ascending” and “Sort descending” must honor their requested direction,
  even when it is already active; do not apply title-click toggling to them.
- **Column names:** Always populate `PlutoColumn.title` with the column's
  readable name, including when `titleSpan` renders a custom header. The column
  selector uses `title`, so an empty title leaves an unnamed selector entry.
- **Header controls:** Avoid duplicate menu and resize icons. Coordinate custom
  header controls with Pluto's built-in controls so each action appears once.
- **Row colors:** Provide a dedicated row-color callback on the shared table
  and forward it through adapters to the underlying grid so feature-specific
  row styling is preserved. The current `AppTable` API does not yet expose
  this callback; add it when integrating row colors rather than relying on
  cell rendering or `onLoaded` to preserve them.
- **Search pickers:** Prefer
  [search_anchor_picker](https://pub.dev/packages/search_anchor_picker) for
  searchable picker controls, including table filters.
