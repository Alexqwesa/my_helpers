import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:my_helpers_flutter/features/meta_pluto_grid/app_table.dart';
import 'package:my_helpers_flutter/features/meta_pluto_grid/table_page_footer.dart';

void main() {
  testWidgets('controlled sort follows the query and leaves server row order intact', (tester) async {
    String? requestedField;
    bool? requestedAscending;
    Future<void> showTable(String field, {required bool ascending}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTable<String>(
              columns: const [
                AppTableColumn(key: 'name', title: 'Name', minWidth: 100),
                AppTableColumn(key: 'updatedAt', title: 'Updated', minWidth: 100),
              ],
              items: const ['second', 'first'],
              revision: 'same-data',
              total: 2,
              rowsPerPage: 10,
              page: 0,
              height: 350,
              sortField: field,
              sortAscending: ascending,
              availableRowsPerPage: const [10, 20],
              cellBuilder: (_, item, _) => Text(item),
              onSort: (field, {required ascending}) {
                requestedField = field;
                requestedAscending = ascending;
              },
              onPageChanged: (_) {},
              onPageSizeChanged: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await showTable('updatedAt', ascending: false);
    var grid = tester.widget<PlutoGrid>(find.byType(PlutoGrid));
    expect(grid.columns.last.sort, PlutoColumnSort.descending);
    expect(grid.rows.map((row) => row.cells['name']!.value), ['second', 'first']);
    grid.columns.first.sort = PlutoColumnSort.ascending;
    grid.onSorted!(PlutoGridOnSortedEvent(column: grid.columns.first, oldSort: PlutoColumnSort.none));
    expect(requestedField, 'name');
    expect(requestedAscending, isTrue);

    await showTable('name', ascending: true);
    grid = tester.widget<PlutoGrid>(find.byType(PlutoGrid));
    expect(grid.columns.first.sort, PlutoColumnSort.ascending);
    expect(grid.columns.last.sort, PlutoColumnSort.none);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden details and selection use the row item; page size preserves position', (tester) async {
    String? selected;
    List<String>? hidden;
    int? newSize;
    int? newPage;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTable<String>(
            columns: const [
              AppTableColumn(key: 'id', title: 'ID', minWidth: 100),
              AppTableColumn(key: 'name', title: 'Name', minWidth: 100),
              AppTableColumn(key: 'comment', title: 'Comment', minWidth: 900, hidePriority: 900),
            ],
            items: const ['row-item'],
            revision: 'page-2',
            total: 100,
            rowsPerPage: 10,
            page: 2,
            height: 350,
            sortField: 'id',
            sortAscending: false,
            availableRowsPerPage: const [10, 20],
            cellBuilder: (_, item, _) => Text(item),
            onSort: (_, {required ascending}) {},
            onPageChanged: (_) {},
            onPageSizeChanged: (size, page) {
              newSize = size;
              newPage = page;
            },
            onRowTap: (item, _) => selected = item,
            onDetails: (item, fields) {
              selected = item;
              hidden = fields;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.info_outline));
    expect(selected, 'row-item');
    expect(hidden, ['comment']);
    selected = null;
    final grid = tester.widget<PlutoGrid>(find.byType(PlutoGrid));
    grid.onSelected!(PlutoGridOnSelectedEvent(row: grid.rows.first, rowIdx: 99));
    expect(selected, 'row-item');
    final footer = tester.widget<TablePagerFooter>(find.byType(TablePagerFooter));
    footer.onRowsPerPageChanged(20);
    expect(newSize, 20);
    expect(newPage, 1);
    expect(tester.takeException(), isNull);
  });
}
