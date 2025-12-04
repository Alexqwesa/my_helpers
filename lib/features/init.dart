import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart';
import 'package:url_strategy/url_strategy.dart';

import 'aloc.dart';

/// {@category UI Root}
final locator = GetIt.instance;

// Future<AppLocalizations> loadDefaultLocale() async {
//   const delegate = AppLocalizations.delegate;
//   final locale = WidgetsBinding.instance.platformDispatcher.locale;
//   if (delegate.isSupported(locale)) {
//     return delegate.load(locale);
//   }
//   return delegate.load(const Locale('en'));
// }
//

/// Main function for initializing whole App, also used in tests.
///
/// Init HiveAdapters, [locator] and [log].
///
/// {@category UI Root}
Future<void> init() async {
  initializeTimeZones();
  setPathUrlStrategy();
  // GoRouter.optionURLReflectsImperativeAPIs = true;
  WidgetsFlutterBinding.ensureInitialized();
  //
  // > logger
  //
  // final log = Logger('vsp');
  // Logger.root.level = Level.ALL;

  // Logger.root.onRecord.listen((record) {
  //   dev.log(
  //     '${record.level.name.substring(0, 3)}:  ${record.message}',
  //   );
  // });
  //
  // > Config from assets/config.json
  //
  // URL = jsonConfig['serverUrl'] ?? URL;
  // FastApiAIURL = jsonConfig['FastApiAIURL'] ?? FastApiAIURL;
  // ElasticURL = jsonConfig['ElasticURL'] ?? ElasticURL;
  // UseMockServer = jsonConfig['UseMockServer'] ?? UseMockServer;
  //
  // > hive adapter
  //
  // HiveCacheStore('dio_cache');
  // try {
  //   // never fail on double adapter registration
  //   Hive
  //     ..registerAdapter(ServiceOfJournalAdapter())
  //     ..registerAdapter(
  //       ServiceStateAdapter(),
  //     );
  //   // ignore: avoid_catching_errors
  // } on HiveError catch (e) {
  //   log.severe(e.toString());
  // }
  //
  // > localization
  //
  // final locale = await loadDefaultLocale(); // todo: use Completer!
  //
  // > locator
  //
  final sharedPreferences = await SharedPreferences.getInstance();
  try {
    locator
      // ..registerLazySingleton<AppLocalizations>(() => locale)
      ..registerLazySingleton<SharedPreferences>(() => sharedPreferences)
      ..registerSingleton<AlocLangOrder>(const AlocLangOrder([]));
    // ignore: avoid_catches_without_on_clauses
    // if (sharedPreferences.getString("LocaleSwitcherCurrentLocaleName") == null) {
    //   await sharedPreferences.setString("LocaleSwitcherCurrentLocaleName", "ru");
    // }
  } catch (e) {
    dev.log(e.toString());
  }
}
