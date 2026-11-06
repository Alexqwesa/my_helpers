import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  group('suppression', () {
    testWidgets(
      'nothing displays before flush; a single error keeps its text',
      (tester) async {
        await mount(tester);
        NotificationService.suppressSnackbars();
        showErrorNotification('Original failure');
        expect(await showAll(tester), isEmpty);
        NotificationService.flushPendingNotifications();
        expect((await showAll(tester)).map((t) => t.text), [
          'Original failure',
        ]);
      },
    );

    testWidgets(
      'errors take priority over successes and pending state clears',
      (tester) async {
        await mount(tester);
        NotificationService.suppressSnackbars();
        showOkNotification('Saved');
        showShortNotification('Copied');
        showWarningNotification('Warning');
        showErrorNotification('First error');
        showErrorNotification('Second error');
        NotificationService.flushPendingNotifications(showOks: true);
        final toasts = await showAll(tester);
        expect(toasts, [(text: '2 errors occurred', color: Colors.red)]);
        NotificationService.flushPendingNotifications(showOks: true);
        expect(await showAll(tester), isEmpty);
        showOkNotification('Fresh success');
        expect((await showAll(tester)).map((t) => t.text), ['Fresh success']);
      },
    );

    testWidgets(
      'successes are opt-in and short notices count toward the summary',
      (tester) async {
        await mount(tester);
        NotificationService.suppressSnackbars();
        showOkNotification('Not requested');
        NotificationService.flushPendingNotifications();
        expect(await showAll(tester), isEmpty);
        NotificationService.suppressSnackbars();
        showOkNotification('Saved');
        showShortNotification('Copied');
        NotificationService.flushPendingNotifications(showOks: true);
        expect(await showAll(tester), [
          (text: '2 operations completed', color: Colors.green),
        ]);
      },
    );

    testWidgets('discarding the queue does not discard suppressed errors', (
      tester,
    ) async {
      await mount(tester);
      showErrorNotification('Cancelled visible request');
      NotificationService.suppressSnackbars();
      showErrorNotification('Pending error');
      NotificationService.discardQueue(dismissCurrent: true);
      NotificationService.flushPendingNotifications();
      expect((await showAll(tester)).map((t) => t.text), ['Pending error']);
    });

    testWidgets(
      'warnings and developer notices do not produce a flush summary',
      (tester) async {
        await mount(tester);
        NotificationService.suppressSnackbars();
        showWarningNotification('Warning');
        showDevNotification('Developer detail');
        NotificationService.flushPendingNotifications(showOks: true);
        expect(await showAll(tester), isEmpty);
      },
    );
  });

  group('notification controls', () {
    testWidgets(
      'copy copies the original message rather than the grouping suffix',
      (tester) async {
        await mount(tester);
        final clipboardWrites = <Object?>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboardWrites.add(call.arguments);
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        showErrorNotification(r'First\nsecond', groupKey: 'copy');
        showErrorNotification('Other text', groupKey: 'copy');
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.copy));
        await tester.pump();
        expect(clipboardWrites, [
          {'text': r'First\nsecond'},
        ]);
        expect(find.text('First\nsecond\n+1 similar'), findsOneWidget);
        await closeNotice(tester);
      },
    );

    testWidgets(
      'close button dismisses the current notice and advances the queue',
      (tester) async {
        await mount(tester);
        await openNotice(tester, 'First');
        showErrorNotification('Next');
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect((await showAll(tester)).map((t) => t.text), ['Next']);
      },
    );

    testWidgets('an explicit timeout dismisses a notice automatically', (
      tester,
    ) async {
      await mount(tester);
      showErrorNotification('Timed', duration: const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Timed'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Timed'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a duplicate does not restart the visible timeout', (
      tester,
    ) async {
      await mount(tester);
      showErrorNotification('Timed', duration: const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      showErrorNotification('Timed', duration: const Duration(seconds: 10));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(await showAll(tester), isEmpty);
    });
  });

  group('flood protection', () {
    testWidgets('explicit groups are separate from unkeyed and other groups', (
      tester,
    ) async {
      await mount(tester);
      showErrorNotification('Same text', groupKey: 'first');
      showErrorNotification('Same text', groupKey: 'second');
      showErrorNotification('Same text');
      expect((await showAll(tester)).map((t) => t.text), [
        'Same text',
        'Same text',
        'Same text',
      ]);
    });

    testWidgets('the same group key never merges different severities', (
      tester,
    ) async {
      await mount(tester);
      showErrorNotification('Failed', groupKey: 'save');
      showWarningNotification('Retrying', groupKey: 'save');
      showOkNotification('Recovered', groupKey: 'save');
      final toasts = await showAll(tester);
      expect(toasts.map((t) => t.text), ['Failed', 'Retrying', 'Recovered']);
      expect(toasts.map((t) => t.color), [
        Colors.red,
        Colors.yellow.shade800,
        Colors.green,
      ]);
    });

    testWidgets('explicit keys override even zero-length prefix grouping', (
      tester,
    ) async {
      await mount(tester);
      NotificationService.configure(similarPrefixLength: 0);
      showErrorNotification('Group one', groupKey: 'one');
      showErrorNotification('Group two', groupKey: 'two');
      showErrorNotification('Different detail', groupKey: 'one');
      showErrorNotification('Unkeyed one');
      showErrorNotification('Unkeyed two');
      expect((await showAll(tester)).map((t) => t.text), [
        'Group one\n+1 similar',
        'Group two',
        'Unkeyed one\n+1 similar',
      ]);
    });

    testWidgets(
      'legacy prefixes never include translations or wrapper fields',
      (tester) async {
        await mount(tester);
        NotificationService.configure(similarPrefixLength: 30);
        showErrorNotification('Saved|Đã lưu|Сохранено');
        showErrorNotification('Saved|Khác|Другое');
        showErrorNotification('prefix|Saved|Khác nữa|Иначе|suffix');
        expect((await showAll(tester)).map((t) => t.text), [
          'Saved\n+2 similar',
        ]);
      },
    );

    testWidgets('a group key can be reused after its notification closes', (
      tester,
    ) async {
      await mount(tester);
      showErrorNotification('First attempt', groupKey: 'save');
      expect((await showAll(tester)).map((t) => t.text), ['First attempt']);
      showErrorNotification('Second attempt', groupKey: 'save');
      expect((await showAll(tester)).map((t) => t.text), ['Second attempt']);
    });

    testWidgets('duplicates still merge when the queue already has overflow', (
      tester,
    ) async {
      await mount(tester);
      NotificationService.configure(maxQueued: 1);
      showErrorNotification('Active', groupKey: 'active');
      showErrorNotification('Waiting', groupKey: 'waiting');
      showErrorNotification('Overflow');
      showErrorNotification('Active detail', groupKey: 'active');
      showErrorNotification('Waiting detail', groupKey: 'waiting');
      expect((await showAll(tester)).map((t) => t.text), [
        'Active\n+1 similar',
        'Waiting\n+1 similar',
        'More notifications: 1',
      ]);
    });

    testWidgets('discard removes overflow and permits new queued messages', (
      tester,
    ) async {
      await mount(tester);
      NotificationService.configure(maxQueued: 1);
      showErrorNotification('Active');
      showErrorNotification('Discarded');
      showErrorNotification('Discarded overflow');
      NotificationService.discardQueue();
      showErrorNotification('New waiting');
      expect((await showAll(tester)).map((t) => t.text), [
        'Active',
        'New waiting',
      ]);
    });

    testWidgets('dismiss a visible group and immediately reuse its key', (
      tester,
    ) async {
      await mount(tester);
      showErrorNotification('Old message', groupKey: 'save');
      await tester.pumpAndSettle();
      NotificationService.discardQueue(dismissCurrent: true);
      showErrorNotification('New message', groupKey: 'save');
      await tester.pumpAndSettle();
      showErrorNotification('New detail', groupKey: 'save');
      expect((await showAll(tester)).map((t) => t.text), [
        'New message\n+1 similar',
      ]);
    });

    testWidgets('different errors sharing a prefix stay separate', (
      tester,
    ) async {
      await mount(tester);
      showErrorNotification(
        'Failed to update records in production DB: deadlock',
      );
      showErrorNotification(
        'Failed to update records in production DB: permission denied',
      );
      expect((await showAll(tester)).map((t) => t.text), [
        'Failed to update records in production DB: deadlock',
        'Failed to update records in production DB: permission denied',
      ]);
    });

    testWidgets('synchronous repeats include the active item before display', (
      tester,
    ) async {
      await mount(tester);
      for (var i = 0; i < 100; i++) {
        showErrorNotification('Same burst');
      }
      expect((await showAll(tester)).map((t) => t.text), ['Same burst']);
    });

    testWidgets('visible repeats merge and update the grouped suffix', (
      tester,
    ) async {
      await mount(tester);
      showErrorNotification('First detail', groupKey: 'operation');
      await tester.pumpAndSettle();
      showErrorNotification('First detail', groupKey: 'operation');
      showErrorNotification('Second detail', groupKey: 'operation');
      await tester.pump();
      expect(find.text('First detail\n+1 similar'), findsOneWidget);
      expect((await showAll(tester)).map((t) => t.text), [
        'First detail\n+1 similar',
      ]);
    });

    testWidgets('group identity is independent of multilingual text', (
      tester,
    ) async {
      await mount(tester);
      showErrorNotification('Saved|Đã lưu|Сохранено', groupKey: 'save');
      showErrorNotification('Saved differently|Khác|Другое', groupKey: 'save');
      expect((await showAll(tester)).map((t) => t.text), ['Saved\n+1 similar']);
    });

    testWidgets(
      'dismiss before first frame cancels without blocking fresh notices',
      (tester) async {
        await mount(tester);
        showErrorNotification('Cancelled');
        NotificationService.discardQueue(dismissCurrent: true);
        showErrorNotification('Fresh');
        expect((await showAll(tester)).map((t) => t.text), ['Fresh']);
      },
    );

    testWidgets('dismiss before first frame never displays the notice', (
      tester,
    ) async {
      await mount(tester);
      showErrorNotification('Cancelled');
      NotificationService.discardQueue(dismissCurrent: true);
      expect(await showAll(tester), isEmpty);
    });

    testWidgets(
      'explicit group keys merge different texts into one "+N similar"',
      (tester) async {
        await mount(tester);
        showErrorNotification('Other problem'); // occupies the screen
        showErrorNotification(
          'Failed to load user with id=1',
          groupKey: 'load-user',
        );
        showErrorNotification(
          'Failed to load user with id=2',
          groupKey: 'load-user',
        );
        showErrorNotification(
          'Failed to load user with id=3',
          groupKey: 'load-user',
        );

        final toasts = await showAll(tester);

        expect(toasts.map((t) => t.text), [
          'Other problem',
          'Failed to load user with id=1\n+2 similar',
        ]);
      },
    );

    testWidgets('identical repeats still collapse without a suffix', (
      tester,
    ) async {
      await mount(tester);
      showErrorNotification('Other problem');
      for (var i = 0; i < 10; i++) {
        showErrorNotification('Same error every time');
      }

      final toasts = await showAll(tester);

      expect(toasts.map((t) => t.text), [
        'Other problem',
        'Same error every time',
      ]);
    });

    testWidgets('different kinds never merge', (tester) async {
      await mount(tester);
      showErrorNotification('Other problem');
      showErrorNotification('Failed to load user with id=1');
      showOkNotification('Failed to load user with id=2');

      final toasts = await showAll(tester);

      expect(toasts.map((t) => t.text), [
        'Other problem',
        'Failed to load user with id=1',
        'Failed to load user with id=2',
      ]);
    });

    testWidgets('only 5 different notifications wait; the rest become one', (
      tester,
    ) async {
      await mount(tester);
      String distinct(int i) => String.fromCharCode(65 + i) * 25;

      showErrorNotification(distinct(0)); // shown at once
      for (var i = 1; i <= 12; i++) {
        showErrorNotification(distinct(i));
      }

      final toasts = await showAll(tester);

      expect(toasts.map((t) => t.text), [
        distinct(0),
        for (var i = 1; i <= 5; i++) distinct(i),
        'More notifications: 7',
      ]);
    });

    testWidgets('the "more" notice takes the most severe colour', (
      tester,
    ) async {
      await mount(tester);
      showOkNotification('Shown first');
      for (var i = 1; i <= 5; i++) {
        showOkNotification(String.fromCharCode(65 + i) * 25);
      }
      showOkNotification('Overflow one, ok');
      showErrorNotification('Overflow two, error');

      final toasts = await showAll(tester);

      expect(toasts.last.text, 'More notifications: 2');
      expect(toasts.last.color, Colors.red);
    });

    testWidgets('the queue accepts new notifications after it drained', (
      tester,
    ) async {
      await mount(tester);
      for (var i = 0; i < 12; i++) {
        showErrorNotification(String.fromCharCode(65 + i) * 25);
      }
      expect((await showAll(tester)).length, 7);

      showErrorNotification('Fresh start');
      expect((await showAll(tester)).map((t) => t.text), ['Fresh start']);
    });

    testWidgets('configure(maxQueued:) changes how many wait', (tester) async {
      await mount(tester);
      NotificationService.configure(maxQueued: 2);
      String distinct(int i) => String.fromCharCode(65 + i) * 25;

      for (var i = 0; i < 8; i++) {
        showErrorNotification(distinct(i));
      }

      expect((await showAll(tester)).map((t) => t.text), [
        distinct(0),
        distinct(1),
        distinct(2),
        'More notifications: 5',
      ]);
    });

    testWidgets(
      'configure(similarPrefixLength:) changes what counts as similar',
      (tester) async {
        await mount(tester);
        NotificationService.configure(similarPrefixLength: 5);
        showErrorNotification('Other problem');
        showErrorNotification('Alpha one');
        showErrorNotification('Alpha two');

        expect((await showAll(tester)).map((t) => t.text), [
          'Other problem',
          'Alpha one\n+1 similar',
        ]);
      },
    );

    test('configure keeps omitted values and rejects bad ones', () {
      NotificationService.debugResetQueue();
      NotificationService.configure(maxQueued: 9);
      expect(NotificationService.maxQueued, 9);
      expect(
        NotificationService.similarPrefixLength,
        NotificationService.defaultSimilarPrefixLength,
      );
      expect(
        () => NotificationService.configure(maxQueued: 0),
        throwsArgumentError,
      );
      expect(
        () => NotificationService.configure(similarPrefixLength: -1),
        throwsArgumentError,
      );
      expect(NotificationService.maxQueued, 9);

      NotificationService.debugResetQueue();
      expect(
        NotificationService.maxQueued,
        NotificationService.defaultMaxQueued,
      );
    });

    testWidgets('discardQueue drops what waits but not what is on screen', (
      tester,
    ) async {
      await mount(tester);
      showErrorNotification('Shown now');
      showErrorNotification('Never shown one');
      showErrorNotification('Never shown two');

      NotificationService.discardQueue();

      expect((await showAll(tester)).map((t) => t.text), ['Shown now']);
    });

    testWidgets(
      'discardQueue(dismissCurrent: true) also hides the visible one',
      (tester) async {
        await mount(tester);
        showErrorNotification('Shown now');
        showErrorNotification('Never shown');
        for (
          var i = 0;
          i < 10 && find.byType(SnackBar).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.byType(SnackBar), findsOneWidget);

        NotificationService.discardQueue(dismissCurrent: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(SnackBar), findsNothing);
        expect(await showAll(tester), isEmpty);
      },
    );
  });
}

typedef Toast = ({String text, Color? color});

/// Lets the queue run to the end and returns what was on screen, in order.
Future<List<Toast>> showAll(WidgetTester tester) async {
  final toasts = <Toast>[];
  for (var guard = 0; guard < 40; guard++) {
    var visible = false;
    for (var i = 0; i < 20 && !visible; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      visible = find.byType(SnackBar).evaluate().isNotEmpty;
    }
    if (!visible) break;
    await tester.pump(const Duration(milliseconds: 400));
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    final text = tester.widget<SelectableText>(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.byType(SelectableText),
      ),
    );
    toasts.add((text: text.data ?? '', color: snackBar.backgroundColor));
    NotificationService.messengerKey.currentState!.clearSnackBars();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }
  return toasts;
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
