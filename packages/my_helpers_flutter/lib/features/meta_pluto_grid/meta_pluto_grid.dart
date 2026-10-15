import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

export 'pluto_pagination_hook.dart';
export 'table_page_footer.dart';

class ResponsivePlutoColumn extends PlutoColumn {
  ResponsivePlutoColumn({
    required super.title,
    required super.field,
    required super.type,
    required this.minW,
    required this.pri,
    this.isFixed = false,
    super.frozen,
    super.enableEditingMode = false,
    super.enableFilterMenuItem = false,
    super.width,
    super.renderer,
    super.titleSpan,
    super.titlePadding,
  });

  /// The absolute minimum width allocated to this column when shrinking before it is entirely hidden.
  final double minW;

  /// Determines the priority for which columns to auto-hide when horizontally constrained (higher number hides first).
  final int pri;

  /// If true, this column is never auto-hidden and never stretched, strictly adhering to its `width` (used for action/info columns).
  final bool isFixed;

  PlutoColumn toPlutoColumn() {
    return PlutoColumn(
      title: title,
      field: field,
      type: type,
      frozen: frozen,
      enableEditingMode: enableEditingMode,
      enableFilterMenuItem: enableFilterMenuItem,
      width: width,
      renderer: renderer,
    );
  }
}

class TableViewController {
  final PlutoBridge bridge = PlutoBridge();
  final ValueNotifier<List<String>> hiddenKeys = ValueNotifier([]);

  List<ResponsivePlutoColumn> _cols = [];
  double lastWidth = 0;

  void setBaseColumns(List<ResponsivePlutoColumn> columns) {
    _cols = columns;
    applyWidth(lastWidth);
  }

  void updateWidth(double w) {
    if (w == lastWidth) return;
    lastWidth = w;
    applyWidth(w);
  }

  void applyWidth(double w) {
    if (_cols.isEmpty || w <= 0 || !bridge.attached) return;

    final sm = bridge._sm;
    if (sm == null) return;

    // Fixed columns calculate their exact predetermined widths unconditionally.
    // They are not candidates for hiding or stretching.
    final fixedCols = _cols.where((c) => c.isFixed).toList();
    final fixedW = fixedCols.fold<double>(0, (s, c) => s + c.width);

    // Account for PlutoGrid's default 1px left + 1px right borders
    // This removes the 2px horizontal scrollbar jumping artifact on resizes.
    final available = w - fixedW - 2.0;

    final dataCols = _cols.where((c) => !c.isFixed).toList();
    final visible = dataCols.map((c) => c.field).toSet();

    double totalMin(Set<String> vis) => vis.fold(0, (s, k) => s + _cols.firstWhere((c) => c.field == k).minW);

    // Hide lowest-priority (highest pri number) columns until content fits
    while (visible.length > 1 && totalMin(visible) > available) {
      var toHide = visible.first;
      var toHidePri = _cols.firstWhere((c) => c.field == toHide).pri;
      for (final k in visible) {
        final pri = _cols.firstWhere((c) => c.field == k).pri;
        if (pri > toHidePri) {
          toHide = k;
          toHidePri = pri;
        }
      }
      visible.remove(toHide);
    }

    final hidden = dataCols.map((c) => c.field).toSet().difference(visible);
    bridge.updateColumnsVisibility(hidden, _cols);

    // Distribute remaining space proportionally: minW acts as flex weight
    final spare = (available - totalMin(visible)).clamp(0.0, double.infinity);
    final totalFlex = totalMin(visible);

    double accumulatedTarget = 0;
    double accumulatedActual = 0;

    final visibleColsToResize = sm.refColumns.originalList.where((c) {
      final isFixedBase = _cols.where((base) => base.field == c.field).firstOrNull?.isFixed ?? false;
      return visible.contains(c.field) && !isFixedBase;
    }).toList();

    for (var i = 0; i < sm.refColumns.originalList.length; i++) {
      final col = sm.refColumns.originalList[i];
      final rpc = _cols.firstWhere((c) => c.field == col.field);

      if (rpc.isFixed) {
        final delta = rpc.width - col.width;
        if (delta.abs() > 0.001) sm.resizeColumn(col, delta);
        continue;
      }

      if (!visible.contains(col.field)) continue;

      final flex = rpc.minW;

      final exactTargetW = flex + (totalFlex > 0 ? spare * flex / totalFlex : 0.0);
      accumulatedTarget += exactTargetW;

      double pixelWidth;
      if (col == visibleColsToResize.last) {
        pixelWidth = accumulatedTarget - accumulatedActual;
      } else {
        pixelWidth = exactTargetW;
      }

      accumulatedActual += pixelWidth;

      final delta = pixelWidth - col.width;
      // Precision update to eliminate empty gaps and jumping
      if (delta.abs() > 0.001) sm.resizeColumn(col, delta);
    }

    final sortedHidden = hidden.toList()..sort();
    if (sortedHidden.join(',') != hiddenKeys.value.join(',')) {
      hiddenKeys.value = sortedHidden;
    }
  }
}

/// UI bridge (controller owns it, widget attaches/detaches the grid).
class PlutoBridge {
  PlutoGridStateManager? _sm;

  bool get attached => _sm != null;

  PlutoGridStateManager? get stateManager => _sm;

  set stateManager(PlutoGridStateManager sm) => _sm = sm;

  void detach(PlutoGridStateManager sm) {
    if (identical(_sm, sm)) _sm = null;
  }

  void updateColumnsVisibility(
    Set<String> hiddenFields,
    List<ResponsivePlutoColumn> baseColumns,
  ) {
    final sm = _sm;
    if (sm == null) return;

    var changed = false;
    for (final col in sm.refColumns.originalList) {
      var hide = false;
      final isFixed = baseColumns.where((c) => c.field == col.field).firstOrNull?.isFixed ?? false;

      if (isFixed) {
        // A fixed column is only hidden if everything except fixed columns are hidden.
        hide = hiddenFields.isEmpty;
      } else {
        hide = hiddenFields.contains(col.field);
      }

      if (col.hide != hide) {
        sm.hideColumn(col, hide);
        changed = true;
      }
    }

    if (changed) {
      sm.refColumns.sort((a, b) {
        final originalA = sm.refColumns.originalList.indexOf(a);
        final originalB = sm.refColumns.originalList.indexOf(b);
        return originalA.compareTo(originalB);
      });
      sm.notifyListeners();
    }
  }

  void replaceRows(List<PlutoRow> rows) {
    final sm = _sm;
    if (sm == null) return;

    try {
      sm
        ..removeAllRows()
        ..appendRows(rows)
        ..notifyListeners();
      return;
    } on Object catch (_) {}

    try {
      sm.refRows
        ..clear()
        ..addAll(rows);
      sm.notifyListeners();
    } on Object catch (_) {
      // If even this fails, do nothing (avoid crash). User will still see previous rows.
    }
  }
}

class ResponsivePlutoGridWidthTracker extends StatelessWidget {
  const ResponsivePlutoGridWidthTracker({
    required this.viewController,
    required this.child,
    super.key,
  });

  final TableViewController viewController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            viewController.updateWidth(c.maxWidth);
          }
        });

        return SizedBox(
          width: c.maxWidth,
          child: child,
        );
      },
    );
  }
}
