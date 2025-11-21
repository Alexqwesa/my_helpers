import 'package:flutter/foundation.dart';
import 'package:locale_switcher/locale_switcher.dart';

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
    // Avoid tight coupling: check by duck-typing.
    final typeName = x.runtimeType.toString(); // e.g., 'Language'
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

      // why it didn't work
      // try {
      //   // 1) Try .name (works for Dart enums and many model classes)
      //   final n = (x as dynamic)._name?.toString();
      //   if (n != null && n.isNotEmpty) return n.toLowerCase();
      // } catch (_) {
      //   // ignore
      // }
      // final n = (x as dynamic).name?.toString();
      // return n?.toLowerCase();
    }

    if (x is String) {
      final n = x.toLowerCase().trim();
      if (n == 'en' || n == 'vi' || n == 'ru') return n;
      // Sometimes value is like 'Language.en' → take suffix
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
  } catch (
  _) {}
  return null;
}

/// Try to produce key candidates for a translations Map
Iterable<dynamic> _langKeyCandidates(String code) sync* {
// Map may be keyed by string codes:
  yield code.toLowerCase(); // 'en'
// yield code.toUpperCase(); // 'EN' (just in case)

// or by int indexes:
  switch (code) {
    case 'en':
      yield 0;
      break;
    case 'vi':
      yield 1;
      break;
    case 'ru':
      yield 2;
      break;
  }

// or by Language enum values (duck-type key equality by .toString or .name)
// We cannot create an actual Language value without importing it,
// so we’ll also try matching known toString patterns when reading.
}

/// Extract a property from either map-like or object-like translation
String? _readProp(dynamic obj, String field) {
  try {
    if (obj == null) return null;

// Case 1: Map-like
    if (obj is Map && obj.containsKey(field)) {
      return safeString(obj[field]);
    }

// Case 2: Object with getters
    final d = obj as dynamic;
    switch (field) {
      case 'name':
        return safeString(d.name);
      case 'shortName':
        return safeString(d.shortName);
      case 'description':
        return safeString(d.description);
      default:
        break;
    }

// Case 3: Object with toJson() returning a map
    if (d?.toJson is Function) {
      final map = (d as dynamic).toJson();
      if (map is Map && map.containsKey(field)) {
        return safeString(map[field]);
      }
    }
  } catch (_) {
// ignore
  }
  return null;
}

/// Pull the appropriate translation object (or map) for the requested language.
/// Supports:
///  - obj.translations: Iterable of objects/maps with .lang or ['lang']
///  - obj.translations: Map keyed by 'en'/'vi'/'ru', by int 0/1/2, or by enum
dynamic getTranslation(dynamic obj, [String? lang]) {
  lang ??= LocaleSwitcher.localeBestMatch.languageCode.toLowerCase();
  if (obj == null) return null;

  try {
// pull 'translations' from map or object
    final trans = obj is Map ? obj['translations'] : (obj as dynamic)?.translations;
    if (trans == null) return null;

// Case A: Iterable of translation entries
    if (trans is Iterable) {
      dynamic best;
      for (final t in trans) {
        if (t == null) continue;
        dynamic raw = (t is Map) ? t['lang'] : (t as dynamic)?.lang;
        final code = normalizeLangCode(raw);
        if (code == lang) {
          return t; // exact match
        }
// fallback bucket: keep first defined as last resort
        best ??= t;
      }
      return best; // maybe null
    }

// Case B: Map keyed by lang variant
    if (trans is Map) {
// 1) direct string/int key hits
      for (final k in _langKeyCandidates(lang)) {
        if (trans.containsKey(k)) return trans[k];
      }

// 2) keys may be Language enum objects → compare by normalized code
      for (final entry in trans.entries) {
        final keyCode = normalizeLangCode(entry.key);
        if (keyCode == lang) return entry.value;
      }
    }
  } catch (e, st) {
    debugPrint('getTranslation($obj) failed: $e\n$st');
  }
  return null;
}

/// Get localized name with fallbacks
String getName(dynamic obj, {String? lang}) {
  lang ??= LocaleSwitcher.localeBestMatch.languageCode.toLowerCase();
  try {
    final langs = [lang, 'en', 'vi', 'ru']; // preference order
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
  lang ??= LocaleSwitcher.localeBestMatch.languageCode.toLowerCase();
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
  lang ??= LocaleSwitcher.localeBestMatch.languageCode.toLowerCase();
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

/// Preferred language order helper.
List<String> _preferredLangs(String? lang) {
  final base = (lang ?? LocaleSwitcher.localeBestMatch.languageCode).toLowerCase();
// Keep simple; duplicates are harmless in the loop below.
  return [base, 'en', 'vi', 'ru'];
}

/// Exact-match translation lookup.
/// Returns the translation entry ONLY if it matches the requested `lang`.
/// No generic fallback to "first" entry.
dynamic getTranslationOrNull(dynamic obj, [String? lang]) {
  final target = (lang ?? LocaleSwitcher.localeBestMatch.languageCode).toLowerCase();
  if (obj == null) return null;

  try {
    final trans = obj is Map ? obj['translations'] : (obj as dynamic)?.translations;
    if (trans == null) return null;

// Case A: Iterable of entries (objects or maps), each with .lang or ['lang']
    if (trans is Iterable) {
      for (final t in trans) {
        if (t == null) continue;
        final raw = (t is Map) ? t['lang'] : (t as dynamic)?.lang;
        final code = normalizeLangCode(raw);
        if (code == target) return t;
      }
      return null;
    }

// Case B: Map keyed by language variants
    if (trans is Map) {
// 1) Try direct key forms
      for (final k in _langKeyCandidates(target)) {
        if (trans.containsKey(k)) return trans[k];
      }
// 2) Keys may be enum/objects; compare by normalized code
      for (final e in trans.entries) {
        if (normalizeLangCode(e.key) == target) return e.value;
      }
    }
  } catch (_) {
// ignore
  }
  return null;
}

/// Localized name without string fallbacks. Returns `null` if not found.
String? getNameOrNull(dynamic obj, {String? lang}) {
  if (obj == null) return null;
  try {
    for (final l in _preferredLangs(lang)) {
      final t = getTranslationOrNull(obj, l);
      final v = _readProp(t, 'name');
      if (v != null) return v;
    }
// Try direct property on the object itself
    final direct = _readProp(obj, 'name');
    if (direct != null) return direct;
  } catch (_) {
// ignore
  }
  return null;
}

/// Localized shortName without string fallbacks. Returns `null` if not found.
/// If shortName is absent, tries `name`; if still absent, returns `null`.
String? getShortNameOrNull(dynamic obj, {String? lang}) {
  try {
    for (final l in _preferredLangs(lang)) {
      final t = getTranslationOrNull(obj, l);
      final s = _readProp(t, 'shortName');
      if (s != null) return s;
      final n = _readProp(t, 'name');
      if (n != null) return n; // graceful fallback to name (still may be null)
    }
    final directShort = _readProp(obj, 'shortName');
    if (directShort != null) return directShort;
    final directName = _readProp(obj, 'name');
    if (directName != null) return directName;
  } catch (_) {
// ignore
  }
  return null;
}
