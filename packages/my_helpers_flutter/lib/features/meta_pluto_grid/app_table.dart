import 'package:flutter/material.dart';
import 'package:my_helpers_flutter/features/aloc.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:my_helpers_flutter/features/meta_pluto_grid/table_page_footer.dart';

/// A controlled, read-only table for server-paginated data.
///
/// The caller owns fetching and query state. Sort events never reorder only the
/// current page; [sortField] and [sortAscending] describe the server's order.
class AppTable<T extends Object> extends StatelessWidget {
  const AppTable({
    required this.columns,
    required this.items,
    required this.revision,
    required this.total,
    required this.rowsPerPage,
    required this.page,
    required this.height,
    required this.sortField,
    required this.sortAscending,
    required this.availableRowsPerPage,
    required this.cellBuilder,
    required this.onSort,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.onRowTap,
    this.onDetails,
    this.onLoaded,
    this.rowHeight = 40,
    super.key,
  }) : assert(rowsPerPage > 0, 'rowsPerPage must be positive'),
       assert(page >= 0, 'page must be zero or greater'),
       assert(height > 0, 'height must be positive'),
       assert(rowHeight > 0, 'rowHeight must be positive');

  final List<AppTableColumn> columns;
  final List<T> items;

  /// Change when data or the server query changes, to recreate the grid.
  final String revision;
  final int total;
  final int rowsPerPage;
  final int page;
  final double height;
  final double rowHeight;
  final String? sortField;
  final bool sortAscending;
  final List<int> availableRowsPerPage;
  final Widget Function(BuildContext context, T item, String field) cellBuilder;
  final void Function(String field, {required bool ascending}) onSort;
  final ValueChanged<int> onPageChanged;

  /// Receives the new size and the page preserving the first visible row.
  final void Function(int size, int page) onPageSizeChanged;
  final void Function(T item, Offset position)? onRowTap;
  final void Function(T item, List<String> hiddenFields)? onDetails;
  final PlutoOnLoadedEventCallback? onLoaded;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const infoWidth = 56.0;
        final visible = _computeVisibleCols(
          maxWidth: constraints.maxWidth,
          all: columns,
          reservedRight: onDetails == null ? 0 : infoWidth,
        );
        final visibleKeys = visible.map((c) => c.key).toSet();
        final hidden = columns.where((c) => !visibleKeys.contains(c.key)).map((c) => c.key).toList();
        final hasInfo = hidden.isNotEmpty && onDetails != null;
        final widths = _scaleWidths(visible, constraints.maxWidth - (hasInfo ? infoWidth : 0));
        final gridColumns = <PlutoColumn>[
          for (final column in visible)
            PlutoColumn(
              field: column.key,
              title: column.header == null ? column.title : '',
              titlePadding: column.header == null ? null : const EdgeInsets.only(left: 8, top: 4, bottom: 4),
              titleSpan: column.header == null
                  ? null
                  : WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Row(
                        children: [
                          Expanded(child: Text(column.title, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 2),
                          column.header!,
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),
              type: PlutoColumnType.text(),
              enableEditingMode: false,
              enableFilterMenuItem: false,
              enableSorting: column.sortable,
              width: widths[column.key]!,
              minWidth: column.minWidth,
              renderer: (ctx) => cellBuilder(context, ctx.cell.value as T, column.key),
            ),
          if (hasInfo)
            PlutoColumn(
              title: '',
              field: '__info__',
              type: PlutoColumnType.text(),
              enableSorting: false,
              enableEditingMode: false,
              enableFilterMenuItem: false,
              width: infoWidth,
              minWidth: infoWidth,
              frozen: PlutoColumnFrozen.end,
              renderer: (ctx) => Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => onDetails!(ctx.cell.value as T, hidden),
                ),
              ),
            ),
        ];
        // This position is scoped to the grid instance; a rebuild resets it.
        var pointerPosition = Offset.zero;
        return SizedBox(
          height: height,
          child: Column(
            children: [
              Expanded(
                child: Listener(
                  onPointerDown: (event) => pointerPosition = event.position,
                  child: PlutoGrid(
                    key: ValueKey('$lang|$revision|${visibleKeys.join(",")}|$sortField|$sortAscending'),
                    columnMenuDelegate: const PlutoColumnMenuDelegateNoAutoFit(),
                    columns: gridColumns,
                    rows: [
                      for (final item in items)
                        PlutoRow(
                          cells: {
                            for (final field in visibleKeys) field: PlutoCell(value: item),
                            if (hasInfo) '__info__': PlutoCell(value: item),
                          },
                        ),
                    ],
                    mode: PlutoGridMode.select,
                    configuration: PlutoGridConfiguration(
                      localeText: buildPlutoLocaleText(lang),
                      style: PlutoGridStyleConfig(
                        rowHeight: rowHeight,
                        columnHeight: 56,
                        gridBorderColor: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    onLoaded: (event) {
                      final sm = event.stateManager
                        ..setFilterOnlyEvent(true)
                        ..setSortOnlyEvent(true)
                        ..setSelectingMode(PlutoGridSelectingMode.row);
                      for (final column in sm.columns) {
                        column.sort = column.field == sortField
                            ? (sortAscending ? PlutoColumnSort.ascending : PlutoColumnSort.descending)
                            : PlutoColumnSort.none;
                      }
                      sm.notifyListeners();
                      onLoaded?.call(event);
                    },
                    onSorted: (event) => onSort(event.column.field, ascending: event.column.sort.isAscending),
                    onSelected: (event) {
                      final row = event.row;
                      if (row == null || row.cells.isEmpty) return;
                      onRowTap?.call(row.cells.values.first.value as T, pointerPosition);
                    },
                  ),
                ),
              ),
              TablePagerFooter(
                total: total,
                rowsPerPage: rowsPerPage,
                currentPage: page,
                availableRowsPerPage: availableRowsPerPage,
                onPageChanged: onPageChanged,
                onRowsPerPageChanged: (size) {
                  if (size != rowsPerPage) onPageSizeChanged(size, (page * rowsPerPage) ~/ size);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

PlutoGridLocaleText buildPlutoLocaleText(String langCode) {
  return PlutoGridLocaleText(
    unfreezeColumn: aloc(
      'Unfreeze|Bỏ cố định|Открепить',
      langCode: langCode,
    ),
    freezeColumnToStart: aloc(
      'Freeze to start|Cố định bên trái|Закрепить в начале',
      langCode: langCode,
    ),
    freezeColumnToEnd: aloc(
      'Freeze to end|Cố định bên phải|Закрепить в конце',
      langCode: langCode,
    ),
    autoFitColumn: aloc(
      'Auto fit|Tự căn độ rộng|Автоматический размер',
      langCode: langCode,
    ),
    hideColumn: aloc(
      'Hide column|Ẩn cột|Скрыть колонку',
      langCode: langCode,
    ),
    setColumns: aloc(
      'Set columns|Chọn cột|Выбрать колонки',
      langCode: langCode,
    ),
    setFilter: aloc(
      'Set filter|Đặt bộ lọc|Установить фильтр',
      langCode: langCode,
    ),
    resetFilter: aloc(
      'Reset filter|Xóa bộ lọc|Сбросить фильтр',
      langCode: langCode,
    ),
    setColumnsTitle: aloc(
      'Column title|Tên cột|Название колонки',
      langCode: langCode,
    ),
    filterColumn: aloc(
      'Column|Cột|Колонка',
      langCode: langCode,
    ),
    filterType: aloc(
      'Type|Kiểu|Тип',
      langCode: langCode,
    ),
    filterValue: aloc(
      'Value|Giá trị|Значение',
      langCode: langCode,
    ),
    filterAllColumns: aloc(
      'All columns|Tất cả cột|Все колонки',
      langCode: langCode,
    ),
    filterContains: aloc(
      'Contains|Chứa|Содержит',
      langCode: langCode,
    ),
    filterEquals: aloc(
      'Equals|Bằng|Равно',
      langCode: langCode,
    ),
    filterStartsWith: aloc(
      'Starts with|Bắt đầu bằng|Начинается с',
      langCode: langCode,
    ),
    filterEndsWith: aloc(
      'Ends with|Kết thúc bằng|Заканчивается на',
      langCode: langCode,
    ),
    filterGreaterThan: aloc(
      'Greater than|Lớn hơn|Больше чем',
      langCode: langCode,
    ),
    filterGreaterThanOrEqualTo: aloc(
      'Greater than or equal to|Lớn hơn hoặc bằng|Больше или равно',
      langCode: langCode,
    ),
    filterLessThan: aloc(
      'Less than|Nhỏ hơn|Меньше чем',
      langCode: langCode,
    ),
    filterLessThanOrEqualTo: aloc(
      'Less than or equal to|Nhỏ hơn hoặc bằng|Меньше или равно',
      langCode: langCode,
    ),
    sunday: aloc('Su|CN|Вс', langCode: langCode),
    monday: aloc('Mo|T2|Пн', langCode: langCode),
    tuesday: aloc('Tu|T3|Вт', langCode: langCode),
    wednesday: aloc('We|T4|Ср', langCode: langCode),
    thursday: aloc('Th|T5|Чт', langCode: langCode),
    friday: aloc('Fr|T6|Пт', langCode: langCode),
    saturday: aloc('Sa|T7|Сб', langCode: langCode),
    hour: aloc('Hour|Giờ|Часы', langCode: langCode),
    minute: aloc('Minute|Phút|Минуты', langCode: langCode),
    loadingText: aloc('Loading|Đang tải|Загрузка', langCode: langCode),
  );
}

class PlutoColumnMenuDelegateNoAutoFit implements PlutoColumnMenuDelegate<PlutoGridColumnMenuItem> {
  const PlutoColumnMenuDelegateNoAutoFit();

  @override
  List<PopupMenuEntry<PlutoGridColumnMenuItem>> buildMenuItems({
    required PlutoGridStateManager stateManager,
    required PlutoColumn column,
  }) {
    final items = const PlutoColumnMenuDelegateDefault().buildMenuItems(
      stateManager: stateManager,
      column: column,
    );

    final filtered = <PopupMenuEntry<PlutoGridColumnMenuItem>>[];
    for (final item in items) {
      final value = item is PopupMenuItem<PlutoGridColumnMenuItem> ? item.value : null;
      if (value == PlutoGridColumnMenuItem.autoFit) {
        continue;
      }
      filtered.add(item);
    }

    while (filtered.isNotEmpty && filtered.first is PopupMenuDivider) {
      filtered.removeAt(0);
    }
    while (filtered.isNotEmpty && filtered.last is PopupMenuDivider) {
      filtered.removeLast();
    }

    for (var i = filtered.length - 1; i > 0; i--) {
      if (filtered[i] is PopupMenuDivider && filtered[i - 1] is PopupMenuDivider) {
        filtered.removeAt(i);
      }
    }

    return filtered;
  }

  @override
  void onSelected({
    required BuildContext context,
    required PlutoGridStateManager stateManager,
    required PlutoColumn column,
    required bool mounted,
    required PlutoGridColumnMenuItem? selected,
  }) {
    const PlutoColumnMenuDelegateDefault().onSelected(
      context: context,
      stateManager: stateManager,
      column: column,
      mounted: mounted,
      selected: selected,
    );
  }
}

class AppTableColumn {
  const AppTableColumn({
    required this.key,
    required this.title,
    required this.minWidth,
    this.fixedWidth,
    this.hidePriority = 0,
    this.header,
    this.sortable = true,
  });

  final String key;
  final String title;
  final double minWidth;
  final double? fixedWidth;
  final int hidePriority;
  final Widget? header;
  final bool sortable;
}

List<AppTableColumn> _computeVisibleCols({
  required double maxWidth,
  required List<AppTableColumn> all,
  required double reservedRight,
}) {
  final visible = [...all];
  var available = maxWidth - reservedRight - 24 - 24;

  while (visible.length > 2) {
    final totalMin = visible.fold<double>(0, (s, c) => s + c.minWidth);
    if (totalMin <= available) break;

    final toHide = visible.reduce(
      (a, b) => a.hidePriority >= b.hidePriority ? a : b,
    );
    visible.remove(toHide);
    available -= 10;
  }

  return visible;
}

Map<String, double> _scaleWidths(List<AppTableColumn> cols, double maxWidth) {
  final fixedTotal = cols.where((c) => c.fixedWidth != null).fold<double>(0, (s, c) => s + c.fixedWidth!);
  final flexibleCols = cols.where((c) => c.fixedWidth == null).toList();
  final flexibleTotal = flexibleCols.fold<double>(0, (s, c) => s + c.minWidth);
  final remaining = maxWidth - fixedTotal;

  if (flexibleCols.isEmpty) {
    return {
      for (final c in cols) c.key: c.fixedWidth ?? c.minWidth,
    };
  }

  if (remaining <= 0 || flexibleTotal <= 0) {
    return {
      for (final c in cols) c.key: c.fixedWidth ?? c.minWidth,
    };
  }

  final scale = remaining / flexibleTotal;
  return {
    for (final c in cols) c.key: c.fixedWidth ?? (c.minWidth * scale),
  };
}
