import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locale_switcher/locale_switcher.dart';
import 'package:my_helpers_flutter/features/init.dart';
import 'package:my_helpers_flutter/features/l10n/locale_switch_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      LangsForSwitcher.name: ['English'],
    });
    locator.registerSingleton<SharedPreferences>(
      await SharedPreferences.getInstance(),
    );
    LocaleSwitcher.readLocales([const Locale('en')]);
  });

  tearDown(() async {
    await locator.reset();
  });

  for (final width in [500.0, 800.0]) {
    for (final showAuto in [false, true]) {
      testWidgets('one language at width $width, showAuto: $showAuto', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(body: LocaleSwitchWidget(showAuto: showAuto)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final switcher = tester.widget<LocaleSwitcher>(
          find.byType(LocaleSwitcher),
        );
        expect(switcher.showOsLocale, showAuto);
        final toggle = find.byType(AnimatedToggleSwitch<LocaleName>);
        if (width >= 600 && showAuto) {
          expect(toggle, findsOneWidget);
          final widget = tester.widget<AnimatedToggleSwitch<LocaleName>>(
            toggle,
          );
          expect(
            widget.values.map((value) => value.name),
            containsAll(['en', systemLocale]),
          );
          expect(widget.values.length, 2);
          widget.onChanged!(
            widget.values.firstWhere((value) => value.name == systemLocale),
          );
          await tester.pumpAndSettle();
          expect(LocaleSwitcher.current.name, systemLocale);
        } else {
          expect(toggle, findsNothing);
          // Open the compact picker to verify that Auto is propagated to its dialog.
          await tester.tap(find.byType(IconButton));
          await tester.pumpAndSettle();
          final dialogSwitchers = tester.widgetList<LocaleSwitcher>(
            find.byType(LocaleSwitcher),
          );
          expect(dialogSwitchers.length, greaterThan(1));
          expect(
            dialogSwitchers.every((entry) => entry.showOsLocale == showAuto),
            isTrue,
          );
        }
      });
    }
  }
}
