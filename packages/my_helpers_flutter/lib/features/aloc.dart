import 'package:flutter/material.dart';
import 'package:locale_switcher/locale_switcher.dart';
import 'package:my_helpers_dart/my_helpers_dart.dart' as dart;

export 'package:my_helpers_dart/my_helpers_dart.dart'
    show AlocLangOrder, preferredAlocLangs, registerAlocLangOrder;

String aloc(String input, {bool all = false, String? langCode}) {
  return dart.aloc(
    input,
    all: all,
    langCode: langCode ?? LocaleSwitcher.localeBestMatch.languageCode,
  );
}

extension AlocBuildContext on BuildContext {
  String aloc(String input, {bool all = false}) {
    final langCode = Localizations.localeOf(this).languageCode;
    return dart.aloc(input, all: all, langCode: langCode);
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
  final lc = Localizations.localeOf(context).languageCode;

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

TextSpan b(String s) => TextSpan(
  text: s,
  style: const TextStyle(fontWeight: FontWeight.bold),
);
