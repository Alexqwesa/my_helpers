import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlutoPaginationState {
  PlutoPaginationState({
    required this.currentPage,
    required this.rowsPerPage,
    required this.setPage,
    required this.setPageSize,
  });

  final int currentPage;
  final int rowsPerPage;
  final ValueChanged<int> setPage;
  final ValueChanged<int> setPageSize;
}

/// A hook to manage PlutoGrid pagination state locally.
/// It provides `currentPage` and `rowsPerPage` state, and callbacks to update them.
///
/// If [storageKey] is provided, it will automatically save and restore the
/// user's explicit `rowsPerPage` preference using `SharedPreferences`. If no
/// key is provided or the user hasn't explicitly set a preference, [defaultRowsPerPage] is used.
PlutoPaginationState usePlutoPaginationState({
  required int defaultRowsPerPage,
  String? storageKey,
}) {
  final currentPage = useState<int>(0);
  final rowsPerPage = useState<int>(defaultRowsPerPage);

  // Initialize from storage once
  useEffect(() {
    if (storageKey == null) return null;

    var isMounted = true;

    unawaited(
      SharedPreferences.getInstance().then((prefs) {
        if (!isMounted) return;
        final savedRows = prefs.getInt(storageKey);
        if (savedRows != null && savedRows > 0) {
          rowsPerPage.value = savedRows;
        }
      }),
    );

    return () {
      isMounted = false;
    };
  }, [storageKey]);

  // Provide callbacks
  final setPage = useCallback<ValueChanged<int>>((page) {
    currentPage.value = page;
  }, []);

  final setPageSize = useCallback<ValueChanged<int>>((size) {
    if (size == rowsPerPage.value) return;

    rowsPerPage.value = size;
    currentPage.value = 0; // Reset to first page when changing size

    if (storageKey != null) {
      unawaited(SharedPreferences.getInstance().then((prefs) => prefs.setInt(storageKey, size)));
    }
  }, [storageKey]);

  return PlutoPaginationState(
    currentPage: currentPage.value,
    rowsPerPage: rowsPerPage.value,
    setPage: setPage,
    setPageSize: setPageSize,
  );
}
