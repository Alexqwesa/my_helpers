import 'package:locale_switcher/locale_switcher.dart';

String aloc(String input, {bool all = false}) {
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

  // if(!context.mounted) return defaultText;
  // final locale = Localizations.localeOf(context).languageCode.toLowerCase();
  final locale = LocaleSwitcher.localeBestMatch.languageCode;

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

