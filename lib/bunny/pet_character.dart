import 'package:flutter/material.dart';

/// A selectable pet: real pixel-art sprite sheets (see
/// assets/sprites/CREDITS.md) + frame maps.
/// Native facing was read off the sheets: cat/dog ship both directions,
/// the bunny sheet only faces left (mirrored at draw time).
class PetCharacter {
  final String id; // 'bunny' | 'cat' | 'dog'
  final String name;
  final String emoji; // picker chip + loading fallback
  final Color trim; // speech-card accent
  final String spriteAsset; // idle/front/tired frames live here
  final String? walkSheet; // when set, walk frames live here instead
  String get walkAsset => walkSheet ?? spriteAsset;
  final List<Rect> walkLeft; // traveling leftward, native pixels
  final List<Rect> walkRight; // traveling rightward, native pixels
  final bool mirrorRight; // walkRight reuses walkLeft rects, drawn mirrored
  final Rect frontFrame; // faces viewer: asking + reactions
  final Rect tiredLeftFrame; // lying down, head left
  final Rect tiredRightFrame; // lying down, head right
  final double walkFps;

  const PetCharacter({
    required this.id,
    required this.name,
    required this.emoji,
    required this.trim,
    required this.spriteAsset,
    this.walkSheet,
    required this.walkLeft,
    required this.walkRight,
    required this.mirrorRight,
    required this.frontFrame,
    required this.tiredLeftFrame,
    required this.tiredRightFrame,
    required this.walkFps,
  });
}

class PetCharacters {
  static const bunny = PetCharacter(
    id: 'bunny',
    name: 'Bunny',
    emoji: '🐰',
    trim: Color(0xFFE3D6F7),
    spriteAsset: 'assets/sprites/bunny.png',
    walkSheet: 'assets/sprites/bunny_walk.png',
    // normalized hop strip: 8 uniform 40x36 cells, feet planted,
    // mass centered (see tool/normalize_sprites.dart)
    walkLeft: [
      Rect.fromLTWH(0, 0, 40, 36),
      Rect.fromLTWH(40, 0, 40, 36),
      Rect.fromLTWH(80, 0, 40, 36),
      Rect.fromLTWH(120, 0, 40, 36),
      Rect.fromLTWH(160, 0, 40, 36),
      Rect.fromLTWH(200, 0, 40, 36),
      Rect.fromLTWH(240, 0, 40, 36),
      Rect.fromLTWH(280, 0, 40, 36),
    ],
    walkRight: [
      Rect.fromLTWH(0, 0, 40, 36),
      Rect.fromLTWH(40, 0, 40, 36),
      Rect.fromLTWH(80, 0, 40, 36),
      Rect.fromLTWH(120, 0, 40, 36),
      Rect.fromLTWH(160, 0, 40, 36),
      Rect.fromLTWH(200, 0, 40, 36),
      Rect.fromLTWH(240, 0, 40, 36),
      Rect.fromLTWH(280, 0, 40, 36),
    ],
    mirrorRight: true,
    frontFrame: Rect.fromLTWH(62, 51, 19, 27),
    tiredLeftFrame: Rect.fromLTWH(62, 51, 19, 27),
    tiredRightFrame: Rect.fromLTWH(62, 51, 19, 27),
    walkFps: 12,
  );

  static const cat = PetCharacter(
    id: 'cat',
    name: 'Cat',
    emoji: '🐱',
    trim: Color(0xFFE8A94B),
    spriteAsset: 'assets/sprites/cat.png',
    walkLeft: [
      Rect.fromLTWH(0, 96, 32, 32),
      Rect.fromLTWH(32, 96, 32, 32),
      Rect.fromLTWH(64, 96, 32, 32),
    ],
    walkRight: [
      Rect.fromLTWH(0, 0, 32, 32),
      Rect.fromLTWH(32, 0, 32, 32),
      Rect.fromLTWH(64, 0, 32, 32),
    ],
    mirrorRight: false,
    frontFrame: Rect.fromLTWH(32, 64, 32, 32),
    tiredLeftFrame: Rect.fromLTWH(96, 96, 32, 32),
    tiredRightFrame: Rect.fromLTWH(96, 0, 32, 32),
    walkFps: 8,
  );

  static const dog = PetCharacter(
    id: 'dog',
    name: 'Dog',
    emoji: '🐶',
    trim: Color(0xFF9C6B30),
    spriteAsset: 'assets/sprites/dog.png',
    walkLeft: [
      Rect.fromLTWH(0, 96, 32, 32),
      Rect.fromLTWH(32, 96, 32, 32),
      Rect.fromLTWH(64, 96, 32, 32),
    ],
    walkRight: [
      Rect.fromLTWH(0, 0, 32, 32),
      Rect.fromLTWH(32, 0, 32, 32),
      Rect.fromLTWH(64, 0, 32, 32),
    ],
    mirrorRight: false,
    frontFrame: Rect.fromLTWH(32, 64, 32, 32),
    tiredLeftFrame: Rect.fromLTWH(96, 96, 32, 32),
    tiredRightFrame: Rect.fromLTWH(96, 0, 32, 32),
    walkFps: 8,
  );

  static const List<PetCharacter> all = [bunny, cat, dog];

  static PetCharacter byId(String? id) =>
      all.firstWhere((c) => c.id == id, orElse: () => bunny);
}

/// Chip row for picking the pet. Used by the app settings and the
/// desktop-pet configuration panel.
class PetPicker extends StatelessWidget {
  final String selectedId;
  final ValueChanged<String> onSelected;

  const PetPicker({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in PetCharacters.all)
          ChoiceChip(
            avatar: Text(c.emoji),
            label: Text(c.name),
            selected: c.id == selectedId,
            onSelected: (_) => onSelected(c.id),
          ),
      ],
    );
  }
}
