import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_helpers_flutter/features/notification_service.dart';

const _screen = Size(800, 1000);
const _dragHandle = Key('notification-drag-hide');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('short notice stays under 30% and has no drag handle', (
    tester,
  ) async {
    await mount(tester);
    try {
      await openNotice(tester, 'Saved');

      expect(find.byKey(_dragHandle), findsNothing);
      expect(
        tester.getSize(find.byType(SnackBar)).height,
        lessThan(_screen.height * 0.3),
      );
    } finally {
      await closeNotice(tester);
    }
  });

  testWidgets(
    'a notice that covers 30% shows a drag handle and stays under 90%',
    (tester) async {
      await mount(tester);
      try {
        await openNotice(tester, List.filled(18, 'Notice').join('\n'));

        final snackBar = find.byType(SnackBar);
        final height = tester.getSize(snackBar).height;

        expect(find.byKey(_dragHandle), findsOneWidget);
        expect(height, greaterThanOrEqualTo(_screen.height * 0.3));
        expect(height, lessThan(_screen.height * 0.8));
      } finally {
        await closeNotice(tester);
      }
    },
  );

  testWidgets('a very long notice caps at 90%, scrolls, and drags away', (
    tester,
  ) async {
    await mount(tester, bottomInset: 48);
    try {
      await openNotice(
        tester,
        List.filled(
          80,
          'A long error line that must stay on screen',
        ).join('\n'),
      );

      final snackBar = find.byType(SnackBar);
      final height = tester.getSize(snackBar).height;
      final top = tester.getTopLeft(snackBar).dy;

      expect(height, lessThanOrEqualTo(_screen.height * 0.9 + 1));
      expect(top, greaterThanOrEqualTo(_screen.height * 0.1 - 1));
      expect(find.byKey(_dragHandle), findsOneWidget);
      final scrollables = tester.stateList<ScrollableState>(
        find.descendant(of: snackBar, matching: find.byType(Scrollable)),
      );
      expect(
        scrollables.any(
          (scrollable) => scrollable.position.maxScrollExtent > 0,
        ),
        isTrue,
      );

      await tester.drag(find.byKey(_dragHandle), const Offset(0, 700));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(SnackBar), findsNothing);
    } finally {
      await closeNotice(tester);
    }
  });

  testWidgets('an open keyboard keeps the notice within the space above it', (
    tester,
  ) async {
    const keyboard = 400.0;
    await mount(tester, keyboard: keyboard);
    try {
      await openNotice(
        tester,
        List.filled(
          80,
          'A long error line that must stay on screen',
        ).join('\n'),
      );

      final snackBar = find.byType(SnackBar);
      final top = tester.getTopLeft(snackBar).dy;
      final bottom = tester.getBottomLeft(snackBar).dy;
      final visibleHeight = _screen.height - keyboard;

      expect(top, greaterThanOrEqualTo(visibleHeight * 0.1 - 1));
      expect(bottom, lessThanOrEqualTo(_screen.height - keyboard + 1));
      expect(
        tester.getSize(snackBar).height,
        lessThanOrEqualTo(visibleHeight * 0.9 + 1),
      );
      expect(find.byKey(_dragHandle), findsOneWidget);
    } finally {
      await closeNotice(tester);
    }
  });
}

Future<void> mount(
  WidgetTester tester, {
  double bottomInset = 0,
  double keyboard = 0,
}) async {
  NotificationService.debugResetQueue();
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(bottom: bottomInset);
  tester.view.viewPadding = FakeViewPadding(bottom: bottomInset);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.view.resetViewInsets);

  await tester.pumpWidget(
    MaterialApp(
      scaffoldMessengerKey: NotificationService.messengerKey,
      home: const Scaffold(body: SizedBox.expand()),
    ),
  );
}

Future<void> openNotice(WidgetTester tester, String message) async {
  showErrorNotification(message);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(SnackBar).evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 400));
      return;
    }
  }
  fail('SnackBar did not appear');
}

Future<void> closeNotice(WidgetTester tester) async {
  NotificationService.messengerKey.currentState?.clearSnackBars();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
