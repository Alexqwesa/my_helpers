import 'package:flutter/foundation.dart';
import 'package:locale_switcher/locale_switcher.dart';

String? _safeString(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty || s.toLowerCase() == 'null' ? null : s;
}

dynamic getTranslation(dynamic obj, [String? lang]) {
  lang ??= LocaleSwitcher.localeBestMatch.languageCode;
  if (obj == null) return null;

  try {
    // Case 1: Map with `translations` key
    final trans =
        obj is Map ? obj['translations'] : (obj as dynamic)?.translations;
    if (trans == null) return null;

    // Case 2: Iterable of translation objects
    if (trans is Iterable) {
      final match = trans.cast<dynamic>().firstWhere(
            (t) {
              if (t == null) return false;
              try {
                return (t is Map ? t['lang'] : (t as dynamic)?.lang) == lang;
              } catch (_) {
                return false;
              }
            },
            orElse: () => null,
          );
      if (match != null) return match;
    }

    // Case 3: Map keyed by language
    if (trans is Map && trans.containsKey(lang)) {
      return trans[lang];
    }
  } catch (e, st) {
    debugPrint('getTranslation($obj) failed: $e\n$st');
  }
  return null;
}

/// Universal helper to read both field and map key safely
String? _readProp(dynamic obj, String field) {
  try {
    if (obj == null) return null;

    // Case 1: Map-like
    if (obj is Map && obj.containsKey(field)) {
      return _safeString(obj[field]);
    }

    // Case 2: Object with field getter
    final d = obj as dynamic;
    switch (field) {
      case 'name':
        return _safeString(d.name);
      case 'shortName':
        return _safeString(d.shortName);
      case 'description':
        return _safeString(d.description);
      default:
        break;
    }

    // Case 3: Object with toJson()
    if ( d?.toJson is Function) {
      final map = (d as dynamic).toJson();
      if (map is Map && map.containsKey(field)) {
        return _safeString(map[field]);
      }
    }
  } catch (_) {
    // ignore
  }
  return null;
}

/// Get localized name with all fallbacks
String getName(dynamic obj, {String? lang}) {
  lang ??= LocaleSwitcher.localeBestMatch.languageCode;
  try {
    final langs = [lang, 'en', 'vi', 'ru'];
    for (final l in langs) {
      final t = getTranslation(obj, l);
      final v = _readProp(t, 'name');
      if (v != null) return v;
    }
    final direct = _readProp(obj, 'name');
    if (direct != null) return direct;
    return 'undefined name of ${obj.runtimeType}';
  } catch (e, st) {
    debugPrint('getName($obj) failed: $e\n$st');
    return 'undefined name of ${obj.runtimeType}';
  }
}

/// Get localized shortName with fallback to name
String getShortName(dynamic obj, {String? lang}) {
  lang ??= LocaleSwitcher.localeBestMatch.languageCode;
  try {
    final langs = [lang, 'en', 'vi', 'ru'];
    for (final l in langs) {
      final t = getTranslation(obj, l);
      final v = _readProp(t, 'shortName');
      if (v != null) return v;
    }
    final direct = _readProp(obj, 'shortName');
    if (direct != null) return direct;
    return getName(obj, lang: lang);
  } catch (e, st) {
    debugPrint('getShortName($obj) failed: $e\n$st');
    return getName(obj, lang: lang);
  }
}

/// Get localized description with fallbacks
String getDescription(dynamic obj, {String? lang}) {
  lang ??= LocaleSwitcher.localeBestMatch.languageCode;
  try {
    final langs = [lang, 'en', 'vi', 'ru'];
    for (final l in langs) {
      final t = getTranslation(obj, l);
      final v = _readProp(t, 'description');
      if (v != null) return v;
    }
    final direct = _readProp(obj, 'description');
    if (direct != null) return direct;
    return getName(obj, lang: lang);
  } catch (e, st) {
    debugPrint('getDescription($obj) failed: $e\n$st');
    return getName(obj, lang: lang);
  }
}
