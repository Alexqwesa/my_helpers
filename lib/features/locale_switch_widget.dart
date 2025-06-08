import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:locale_switcher/locale_switcher.dart';
import 'package:my_helpers/features/init.dart';
import 'package:my_helpers/features/locale.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// {@category UI Root}
// final locator = GetIt.instance;

class LangsForSwitcher extends StateNotifier<List<String>> {
  static const name = 'LangsForSwitcher_';

  LangsForSwitcher()
      : super(locator<SharedPreferences>().getStringList(name) ?? ['Русский', 'Tiếng Việt']);

  void add(String loc) {
    if (!state.contains(loc)) {
      state = [...state, loc];
      locator<SharedPreferences>().setStringList(name, state);
    }
  }

  void remove(String loc) {
    if (state.contains(loc)) {
      state = state.where((e) => e != loc).toList();
      locator<SharedPreferences>().setStringList(name, state);
    }
  }
}

final langsForSwitcherProvider =
    StateNotifierProvider<LangsForSwitcher, List<String>>((ref) => LangsForSwitcher());

class LocaleSwitchWidget extends ConsumerWidget {
  const LocaleSwitchWidget({super.key});

  @override
  Widget build(BuildContext context, ref) {
    const size = .910;
    final langs = ref.watch(langsForSwitcherProvider);
    WidgetsFlutterBinding.ensureInitialized();

    // final width = MediaQueryData.fromView(View.of(context)).size.width;
    final width = MediaQuery.of(context).size.width;
    if (width < 600 || langs.length == 1) {
      return const LocaleSwitcher.iconButton(multiLangCountries: MultiLangCountries.onlyFlag);
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          width: langs.length * 50,
          child: LocaleSwitcher.custom(
            // numberOfShown: 2,
            builder: (langCodes1, context) {
              final langCodes = SupportedLocaleNames.fromEntries(
                langCodes1.where((lc) => langs.contains(lc.language)),
              );
              if (langCodes.length <= 1) {
                // AnimatedToggleSwitch crash with one value
                langCodes.addShowOtherLocales();
              }

              return AnimatedToggleSwitch<LocaleName>.rolling(
                values: langCodes,
                borderWidth: 0,
                height: 48 * size,
                indicatorSize: const Size(48 * size, 48 * size),
                fittingMode: FittingMode.none,
                current: LocaleSwitcher.current,
                onChanged: (langCode) {
                  if (langCode.name == showOtherLocales) {
                    showSelectLocaleDialog(context);
                  } else {
                    LocaleSwitcher.current = langCode;
                  }
                },
                iconBuilder:
                    (lang, foreground) => LangIconWithToolTip(
                      multiLangCountries: MultiLangCountries.onlyFlag,
                      localeNameFlag: lang,
                    ),
                allowUnlistedValues: true,
                loading: false,
                style: ToggleStyle(
                  backgroundColor: Colors.black12,
                  indicatorColor: context.theme.colorScheme.primaryContainer,
                ),
              );
            },
            // shape: circleOrSquare? const CircleBorder(eccentricity: 0) : null,
          ),
        ),
      );
    }
  }
}
