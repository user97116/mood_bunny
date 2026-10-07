import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mood_bunny/bunny/bunny_host.dart';

void main() {
  testWidgets('bunny appears as Flutter overlay over any route',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: BunnyHost(
          child: Scaffold(body: Text('app content')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('app content'), findsOneWidget);
    expect(find.text('Hi! How are you feeling?'), findsNothing);

    // Summon via host API — inserts an OverlayEntry, no desktop plugin.
    final ctx =
        tester.element(find.text('app content'));
    BunnyHost.of(ctx)!.summonNow();
    await tester.pump(); // insert entry
    // Image codecs resolve on real async, not fake-async pumps: yield
    // real time so the sprite sheet decodes, then continue on fake time.
    await tester.runAsync(() => Future.delayed(
        const Duration(milliseconds: 500)));
    await tester.pump();
    await tester.pump(
        const Duration(milliseconds: 300)); // slide underway

    // Mid-journey the bunny must be far from center (came from an edge,
    // not popped at center). Side is random, so assert distance only.
    final midX =
        tester.getCenter(find.text('Hi! How are you feeling?')).dx;
    expect((midX - 400).abs(), greaterThan(150));

    // The walk cycle must advance while traveling: two snapshots of the
    // sprite frame key 200ms apart must differ (default bunny: 8 frames
    // at 12fps -> new frame every ~83ms).
    Rect frameKey() {
      final brush = tester.widgetList<CustomPaint>(find.byWidgetPredicate(
          (w) => w is CustomPaint && w.key is ValueKey<Rect>));
      expect(brush.isNotEmpty, isTrue);
      return (brush.first.key! as ValueKey<Rect>).value;
    }

    final frameA = frameKey();
    await tester.pump(const Duration(milliseconds: 200));
    final frameB = frameKey();
    expect(frameB, isNot(equals(frameA)));

    await tester.pump(
        const Duration(milliseconds: 1000)); // slide-in done (1400ms trip)
    await tester.pump(
        const Duration(milliseconds: 300)); // flush completion + rebuild
    expect(find.text('Hi! How are you feeling?'), findsOneWidget);
    expect(find.textContaining('Happy'), findsOneWidget);

    // Pick a mood -> reaction shows, entry saved locally.
    await tester.tap(find.textContaining('Happy').first);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('saved!'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('bunny_moods_v1'), contains('happy'));

    // Let reaction (1.9s) + slide-out (1400ms) finish so no timer
    // is pending at teardown, then bunny is gone back to its edge.
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('Hi! How are you feeling?'), findsNothing);
  });
}
