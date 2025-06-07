
import 'package:flutter/material.dart';

// Future<AppLocalizations> loadDefaultLocale() async {
//   const delegate = AppLocalizations.delegate;
//   final locale = WidgetsBinding.instance.platformDispatcher.locale;
//   if (delegate.isSupported(locale)) {
//     return delegate.load(locale);
//   }
//   return delegate.load(const Locale('en'));
// }


extension Helpers on BuildContext {
  // Usage example: `context.theme`
  ThemeData get theme => Theme.of(this);

  // AppLocalizations get s => AppLocalizations.of(this) ?? tr();
}