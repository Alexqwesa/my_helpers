String? safeString(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty || s.toLowerCase() == 'null' ? null : s;
}

/// Normalize any language representation to 'en'|'vi'|'ru'
String? normalizeLangCode(dynamic x) {
  if (x == null) return null;
  try {
    final index = (x as dynamic).index;
    if (index is int) {
      switch (index) {
        case 0:
          return 'en';
        case 1:
          return 'vi';
        case 2:
          return 'ru';
      }
    }
  } catch (_) {
    // Ignore if .index is not accessible
  }

  try {
    final typeName = x.runtimeType.toString();
    if (typeName == 'Language') {
      switch ((x as dynamic).index) {
        case 0:
          return 'en';
        case 1:
          return 'vi';
        case 2:
          return 'ru';
      }
      return null;
    }

    if (x is String) {
      final n = x.toLowerCase().trim();
      if (n == 'en' || n == 'vi' || n == 'ru') return n;
      final m = RegExp(r'([a-z]{2})$').firstMatch(n);
      if (m != null) {
        final sfx = m.group(1)!;
        if (sfx == 'en' || sfx == 'vi' || sfx == 'ru') return sfx;
      }
      return null;
    }

    if (x is int) {
      switch (x) {
        case 0:
          return 'en';
        case 1:
          return 'vi';
        case 2:
          return 'ru';
      }
      return null;
    }
  } catch (_) {}
  return null;
}
