import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mood_bunny/bunny/bunny_scheduler.dart';
import 'package:mood_bunny/bunny/mood_entry.dart';
import 'package:mood_bunny/bunny/mood_store.dart';
import 'package:mood_bunny/bunny/pet_character.dart';

void main() {
  test('planDayVisits spreads visits across the day, sorted', () {
    final day = DateTime(2026, 10, 5);
    final visits = BunnySchedule.planDayVisits(
      day: day,
      count: 4,
      startHour: 9,
      endHour: 22,
      random: Random(42),
    );
    expect(visits.length, 4);
    for (var i = 1; i < visits.length; i++) {
      expect(visits[i].isAfter(visits[i - 1]), isTrue);
    }
    for (final v in visits) {
      expect(v.hour >= 9 && v.hour <= 22, isTrue);
    }
  });

  test('nextVisitAfter picks the next future slot', () {
    final now = DateTime(2026, 10, 5, 12, 0);
    final plan = [
      DateTime(2026, 10, 5, 9, 30),
      DateTime(2026, 10, 5, 13, 0),
      DateTime(2026, 10, 5, 18, 0),
    ];
    expect(BunnySchedule.nextVisitAfter(now, plan),
        DateTime(2026, 10, 5, 13, 0));
    expect(
        BunnySchedule.nextVisitAfter(DateTime(2026, 10, 5, 19, 0), plan),
        isNull);
  });

  test('mood encode/decode round-trips', () {
    final entries = [
      MoodEntry(at: DateTime(2026, 10, 5, 10, 0), mood: 'happy'),
      MoodEntry(at: DateTime(2026, 10, 5, 12, 0), mood: 'sad', note: 'tired'),
    ];
    final raw = MoodStore.encode(entries);
    final back = MoodStore.decode(raw);
    expect(back.length, 2);
    expect(back.first.mood, 'sad'); // sorted newest first
    expect(back.last.mood, 'happy');
    final single = MoodEntry.fromJson(entries.first.toJson());
    expect(single.mood, 'happy');
  });

  test('BunnyConfig defaults to 4 visits/day', () {
    const c = BunnyConfig();
    expect(c.visitsPerDay, 4);
    expect(c.useCustomInterval, isFalse);
    expect(c.autoHideSeconds, 60);
    expect(c.side, 'random');
    final copy = c.copyWith(visitsPerDay: 5, useCustomInterval: true);
    expect(copy.visitsPerDay, 5);
    expect(copy.useCustomInterval, isTrue);
  });

  test('BunnyConfig JSON round-trips all fields', () {
    const c = BunnyConfig(
      visitsPerDay: 3,
      useCustomInterval: true,
      intervalMinutes: 45,
      startHour: 8,
      endHour: 20,
      autoHideSeconds: 90,
      side: 'left',
      pet: 'cat',
    );
    final back = BunnyConfig.fromJson(
        Map<String, dynamic>.from(c.toJson()));
    expect(back.visitsPerDay, 3);
    expect(back.useCustomInterval, isTrue);
    expect(back.intervalMinutes, 45);
    expect(back.startHour, 8);
    expect(back.endHour, 20);
    expect(back.autoHideSeconds, 90);
    expect(back.side, 'left');
    expect(back.pet, 'cat');
  });

  test('pets have sprite data with safe fallback', () {
    expect(PetCharacters.all.map((p) => p.id),
        containsAll(['bunny', 'cat', 'dog']));
    // Sheet bounds: walk sheet + sprite sheet per pet.
    final walkBounds = {
      'assets/sprites/cat.png': [512, 256],
      'assets/sprites/dog.png': [512, 256],
      'assets/sprites/bunny_walk.png': [320, 36],
    };
    final spriteBounds = {
      'assets/sprites/cat.png': [512, 256],
      'assets/sprites/dog.png': [512, 256],
      'assets/sprites/bunny.png': [321, 327],
    };
    for (final pet in PetCharacters.all) {
      expect(pet.spriteAsset.endsWith('.png'), isTrue);
      expect(pet.walkLeft.isNotEmpty, isTrue);
      expect(pet.walkLeft.length, pet.walkRight.length);
      expect(pet.walkFps, greaterThan(0));
      final wb = walkBounds[pet.walkAsset]!;
      for (final f in [...pet.walkLeft, ...pet.walkRight]) {
        expect(f.right, lessThanOrEqualTo(wb[0]),
            reason: '${pet.id} walk frame $f exceeds sheet');
        expect(f.bottom, lessThanOrEqualTo(wb[1]),
            reason: '${pet.id} walk frame $f exceeds sheet');
      }
      final sb = spriteBounds[pet.spriteAsset]!;
      for (final f in [
        pet.frontFrame,
        pet.tiredLeftFrame,
        pet.tiredRightFrame,
      ]) {
        expect(f.right, lessThanOrEqualTo(sb[0]),
            reason: '${pet.id} frame $f exceeds sheet');
        expect(f.bottom, lessThanOrEqualTo(sb[1]),
            reason: '${pet.id} frame $f exceeds sheet');
      }
    }
    // Unknown ids fall back to bunny.
    expect(PetCharacters.byId('dragon'), PetCharacters.bunny);
    expect(PetCharacters.byId(null), PetCharacters.bunny);
  });

  test('scheduler honors fixed entry side', () {
    var fired = 0;
    final s = BunnyScheduler(onVisit: () => fired++);
    s.updateConfig(const BunnyConfig(side: 'left'),
        now: DateTime(2026, 10, 5, 8, 0));
    s.summonNow();
    expect(fired, 1);
    expect(s.nextSide, BunnySide.left);
    s.updateConfig(const BunnyConfig(side: 'right'),
        now: DateTime(2026, 10, 5, 8, 0));
    s.summonNow();
    expect(fired, 2);
    expect(s.nextSide, BunnySide.right);
    s.stop();
  });
}
