
import 'package:flutter/material.dart';


extension Helpers on BuildContext {
  // Usage example: `context.theme`
  ThemeData get theme => Theme.of(this);

  // AppLocalizations get s => AppLocalizations.of(this) ?? tr();
}