import 'package:locale_switcher/locale_switcher.dart';
import 'package:flutter/material.dart';
import 'init.dart';

/// Configuration for how `aloc(all: true)` should order / filter languages.
class AlocLangOrder {
  AlocLangOrder(this.langs);

  /// Language codes in preferred order, e.g. ['ru', 'vi'].
  final List<String> langs;
}

List<String>? preferredAlocLangs() {
  if (!locator.isRegistered<AlocLangOrder>()) return null;
  return locator<AlocLangOrder>().langs;
}

String aloc(String input, {bool all = false, String? langCode}) {
  // todo: maybe check arb first?
  if (all) {
    return input.replaceAll("|", " / ");
  }

  // final context = navigatorKey.currentContext;
  // if (context == null) return input.split('|').first;

  final parts = input.split('|');

  final defaultText = parts.isNotEmpty ? parts[0] : '';
  final viText = parts.length > 1 ? parts[1] : defaultText;
  final ruText = parts.length > 2 ? parts[2] : defaultText;

  final pref = preferredAlocLangs();
  if (pref != null && pref.isNotEmpty) {
    final map = <String, String>{'en': defaultText, 'vi': viText, 'ru': ruText};
    final out = <String>[];
    for (final code in pref) {
      final text = map[code];
      if (text != null && text.isNotEmpty) {
        out.add(text);
      }
    }
    if (out.isNotEmpty) {
      return out.join(' / ');
    }
  }

  // if(!context.mounted) return defaultText;
  // final locale = Localizations.localeOf(context).languageCode.toLowerCase();
  final locale =
      (langCode ?? LocaleSwitcher.localeBestMatch.languageCode).toLowerCase();

  if (locale == 'vi') return viText;
  if (locale == 'ru') return ruText;

  // todo support AppLocalizations here
  return defaultText;
}

extension StringX on String? {
  /// Returns `null` if the string is `null`, empty, or contains only spaces.
  String? get nullIfBlank {
    final s = this?.trim();
    return (s == null || s.isEmpty || s.toLowerCase() == 'null') ? null : s;
  }
}

TextSpan alocSpan({
  required BuildContext context,
  required List<InlineSpan> en,
  required List<InlineSpan> vi,
  required List<InlineSpan> ru,
  TextStyle? style,
}) {
  final baseStyle = style ?? Theme.of(context).textTheme.bodyMedium;
  final lc = LocaleSwitcher.localeBestMatch.languageCode;

  List<InlineSpan> pick() {
    switch (lc) {
      case 'vi':
        return vi;
      case 'ru':
        return ru;
      default:
        return en;
    }
  }

  return TextSpan(style: baseStyle, children: pick());
}

/// Convenience builders
TextSpan t(String s) => TextSpan(text: s);

TextSpan b(String s) =>
    TextSpan(text: s, style: const TextStyle(fontWeight: FontWeight.bold));
