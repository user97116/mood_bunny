import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bunny_scheduler.dart';
import 'mood_entry.dart';
import 'pet_character.dart';

enum _Phase { entering, asking, reacting, exiting }

/// The sliding pet. Comes from [side] at vertical center,
/// asks mood, reacts, then hops back and disappears.
class BunnyOverlay extends StatefulWidget {
  final BunnySide side;
  final PetCharacter character;
  final ValueChanged<String> onMoodSelected;
  final VoidCallback onGone;

  /// Seconds before the bunny gives up and leaves on its own.
  final int autoHideSeconds;

  const BunnyOverlay({
    super.key,
    required this.side,
    this.character = PetCharacters.bunny,
    required this.onMoodSelected,
    required this.onGone,
    this.autoHideSeconds = 60,
  });

  @override
  State<BunnyOverlay> createState() => _BunnyOverlayState();
}

class _BunnyOverlayState extends State<BunnyOverlay>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.entering;
  String? _pickedMood;

  late final AnimationController _slide;
  late final AnimationController _hop;
  late final AnimationController _react;
  late final AnimationController _walk; // cycles sprite walk frames
  Timer? _autoHide;

  double get _sideSign => widget.side == BunnySide.left ? -1.0 : 1.0;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      // Slow enough that the full edge -> center journey is unmistakable.
      duration: const Duration(milliseconds: 1400),
    );
    // Start off-screen.
    _slide.value = 0.0;
    _hop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..repeat(reverse: true);
    _react = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // Walk-cycle clock for the sprite frames (one loop per
    // frames/fps seconds, repeating while the pet travels).
    final walkLen = widget.character.walkLeft.length.clamp(1, 64);
    _walk = AnimationController(
      vsync: this,
      duration: Duration(
          milliseconds:
              (1000 * walkLen / widget.character.walkFps).round()),
    )..repeat();

    // Slide in after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slide.forward().then((_) {
        if (mounted) setState(() => _phase = _Phase.asking);
      });
    });

    _autoHide = Timer(Duration(seconds: widget.autoHideSeconds), () {
      if (mounted && (_phase == _Phase.asking || _phase == _Phase.entering)) {
        _leave();
      }
    });
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    _slide.dispose();
    _hop.dispose();
    _react.dispose();
    _walk.dispose();
    super.dispose();
  }

  void _pick(String moodId) {
    if (_phase != _Phase.asking) return;
    setState(() {
      _phase = _Phase.reacting;
      _pickedMood = moodId;
    });
    _autoHide?.cancel();
    _react.forward(from: 0);
    widget.onMoodSelected(moodId);
    // Let the user enjoy the reaction, then leave.
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) _leave();
    });
  }

  void _leave() {
    if (_phase == _Phase.exiting) return;
    setState(() => _phase = _Phase.exiting);
    _autoHide?.cancel();
    // Animate back to origin side, then notify.
    _slide.reverse().then((_) {
      if (mounted) widget.onGone();
    });
  }

  String get _reactionEmoji {
    switch (_pickedMood) {
      case 'happy':
        return '💛';
      case 'sad':
        return '💗';
      case 'stressed':
        return '🌿';
      case 'tired':
        return '🌙';
      default:
        return '✨';
    }
  }

  String get _reactionText {
    switch (_pickedMood) {
      case 'happy':
        return 'Yay! Happy wiggle!';
      case 'sad':
        return 'Oh no… snuggle time.';
      case 'stressed':
        return 'Breathe with me… in… out…';
      case 'tired':
        return 'Shhh… rest well.';
      default:
        return 'Noted! *nod nod*';
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Start fully beyond the screen edge (half screen + full bunny width).
    final offscreen = (width / 2 + 340) * _sideSign;

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: Listenable.merge([_slide, _hop]),
        builder: (context, child) {
          // slide 0 = beyond edge, 1 = center. Eased so arrival is soft,
          // and the same curve in reverse eases the departure.
          final t = Curves.easeInOutCubic.transform(_slide.value);
          final dx = offscreen * (1.0 - t);
          // Travel bounce while entering/exiting, gentle bob while asking.
          final hopAmp = _phase == _Phase.entering || _phase == _Phase.exiting
              ? 14.0
              : 7.0;
          final dy = -hopAmp * _hop.value;
          return Transform.translate(
            offset: Offset(dx, dy),
            child: child,
          );
        },
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            // Center the sprite against the card (bottom-aligning sank
            // it below the card's visual middle).
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Rebuilt on every walk-clock tick so the sprite frames
              // advance. (Must NOT be the cached `child` above, or the
              // walk cycle freezes on its first frame.)
              AnimatedBuilder(
                animation: _walk,
                builder: (_, _) {
                  final entering = _phase == _Phase.entering;
                  final exiting = _phase == _Phase.exiting;
                  // Entry heads center-ward; exit heads back to origin,
                  // so the sprite always faces its travel direction.
                  final movingRight =
                      (widget.side == BunnySide.left) == entering;
                  return _PetFigure(
                    character: widget.character,
                    frameIndex: (_walk.value *
                            widget.character.walkLeft.length)
                        .floor(),
                    walking: entering || exiting,
                    movingRight: movingRight,
                    fromLeft: widget.side == BunnySide.left,
                    reactController: _react,
                    moodId:
                        _phase == _Phase.reacting ? _pickedMood : null,
                  );
                },
              ),
              const SizedBox(width: 12),
              _SpeechCard(
                phase: _phase,
                petEmoji: widget.character.emoji,
                accent: widget.character.trim,
                pickedMood: _pickedMood,
                reactionEmoji: _reactionEmoji,
                reactionText: _reactionText,
                onPick: _pick,
                onSkip: _leave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeechCard extends StatelessWidget {
  final _Phase phase;
  final String petEmoji;
  final Color accent;
  final String? pickedMood;
  final String reactionEmoji;
  final String reactionText;
  final ValueChanged<String> onPick;
  final VoidCallback onSkip;

  const _SpeechCard({
    required this.phase,
    required this.petEmoji,
    required this.accent,
    required this.pickedMood,
    required this.reactionEmoji,
    required this.reactionText,
    required this.onPick,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final reacting = phase == _Phase.reacting;
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent),
        boxShadow: const [
          BoxShadow(
              blurRadius: 24, color: Colors.black26, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$petEmoji  ', style: const TextStyle(fontSize: 16)),
              Flexible(
                child: Text(
                  reacting ? reactionText : 'Hi! How are you feeling?',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!reacting)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in BunnyMoods.all)
                  _MoodChip(
                    emoji: m.emoji,
                    label: m.label,
                    onTap: () => onPick(m.id),
                  ),
                TextButton(
                  onPressed: onSkip,
                  child: const Text('skip'),
                ),
              ],
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(reactionEmoji,
                    style: const TextStyle(fontSize: 34)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${BunnyMoods.byId(pickedMood ?? 'okay').emoji} saved!',
                    style: const TextStyle(color: Colors.green),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;
  const _MoodChip(
      {required this.emoji, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F1FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDCCFF7)),
        ),
        child: Text('$emoji $label', style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}

/// Sprite-animated pet (real pixel-art frames from assets/sprites).
/// Cycles [character.walkFrames] while [walking] (entering/exiting),
/// shows the idle/tired frame otherwise. Reaction bounce via
/// [reactController], horizontal flip for right-side entries.
class _PetFigure extends StatelessWidget {
  final PetCharacter character;
  final int frameIndex;
  final bool walking;
  /// Which way the pet is (or was) moving: true = rightward.
  /// On exit it returns to its origin, so this flips vs entry.
  final bool movingRight;
  /// Which edge it came from: picks the lying-down side for sad/tired.
  final bool fromLeft;
  final String? moodId;
  final AnimationController reactController;
  const _PetFigure({
    required this.character,
    required this.frameIndex,
    required this.walking,
    required this.movingRight,
    required this.fromLeft,
    required this.moodId,
    required this.reactController,
  });

  @override
  Widget build(BuildContext context) {
    final reacting = moodId != null;
    final Rect src;
    final String asset;
    final bool flip;
    if (walking || moodId == 'happy') {
      // Traveling feet, or a happy dance in place.
      final frames =
          movingRight ? character.walkRight : character.walkLeft;
      src = frames[frameIndex % frames.length];
      asset = character.walkAsset;
      flip = movingRight && character.mirrorRight;
    } else if (moodId == 'sad' || moodId == 'tired') {
      // Downcast moods slump into the lying-down sprite.
      src = fromLeft
          ? character.tiredRightFrame
          : character.tiredLeftFrame;
      asset = character.spriteAsset;
      flip = fromLeft && character.mirrorRight;
    } else {
      // Asking + other reactions: face the viewer.
      src = character.frontFrame;
      asset = character.spriteAsset;
      flip = false;
    }
    return AnimatedBuilder(
      animation: reactController,
      builder: (context, child) {
        final t = reactController.value;
        // Bounce + wiggle on reaction.
        final scale = reacting ? 1.0 + 0.25 * sin(t * pi) : 1.0;
        final rot = reacting ? 0.15 * sin(t * pi * 2) : 0.0;
        return Transform.scale(
          scale: scale,
          child:
              Transform.rotate(angle: rot * (fromLeft ? -1 : 1), child: child),
        );
      },
      child: SizedBox(
        width: 140,
        height: 140,
        child: Stack(
          children: [
            _SpriteImage(
                character: character,
                asset: asset,
                src: src,
                // Idle poses are smaller art: scale up to match walk size.
                scale: walking ? 3.5 : 4.0,
                flipped: flip),
            if (reacting)
              Positioned(
                top: 0,
                right: 0,
                child: Text(
                  moodId == 'happy'
                      ? '🎉'
                      : moodId == 'sad'
                          ? '💗'
                          : moodId == 'stressed'
                              ? '🍃'
                              : moodId == 'tired'
                                  ? '💤'
                                  : '✨',
                  style: const TextStyle(fontSize: 26),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Loads + caches the sheet, draws one frame bottom-centered and crisp
/// (nearest-neighbor so pixels stay sharp).
class _SpriteImage extends StatefulWidget {
  final PetCharacter character;
  final String asset;
  final Rect src;
  final bool flipped;
  /// Small idle/front frames render bigger so the pet keeps a
  /// consistent on-screen size across states.
  final double scale;
  const _SpriteImage(
      {required this.character,
      required this.asset,
      required this.src,
      required this.flipped,
      this.scale = 3.5});

  @override
  State<_SpriteImage> createState() => _SpriteImageState();
}

class _SpriteImageState extends State<_SpriteImage> {
  ui.Image? _img;
  String? _loadedAsset;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _SpriteImage old) {
    super.didUpdateWidget(old);
    if (old.asset != widget.asset) _load();
  }

  Future<void> _load() async {
    try {
      final img = await PetSheetCache.load(widget.asset);
      if (!mounted) return;
      // Keep showing the old sheet until the new one is ready.
      setState(() {
        _img = img;
        _loadedAsset = widget.asset;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final img = _img;
    if (img == null || _loadedAsset != widget.asset) {
      return Center(
        child: Text(widget.character.emoji,
            style: const TextStyle(fontSize: 64)),
      );
    }
    return CustomPaint(
      // Keyed by frame so tests (and the framework) can see frame changes.
      key: ValueKey(widget.src),
      painter: _SpritePainter(
          img: img,
          src: widget.src,
          flipped: widget.flipped,
          scale: widget.scale),
    );
  }
}

class _SpritePainter extends CustomPainter {
  final ui.Image img;
  final Rect src;
  final bool flipped;
  final double scale;
  _SpritePainter(
      {required this.img,
      required this.src,
      required this.flipped,
      required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final dw = src.width * scale;
    final dh = src.height * scale;
    final dst =
        Rect.fromLTWH((size.width - dw) / 2, size.height - dh, dw, dh);
    final paint = Paint()..filterQuality = FilterQuality.none;
    if (!flipped) {
      canvas.drawImageRect(img, src, dst, paint);
    } else {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
      canvas.drawImageRect(img, src, dst, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SpritePainter old) =>
      old.src != src ||
      old.flipped != flipped ||
      old.img != img ||
      old.scale != scale;
}

/// Shared sprite-sheet cache. Warmed at startup so the first visit
/// paints sprites instantly instead of flashing the emoji fallback.
class PetSheetCache {
  static final Map<String, ui.Image> _sheets = {};

  static Future<ui.Image> load(String asset) async {
    final hit = _sheets[asset];
    if (hit != null) return hit;
    final data = await rootBundle.load(asset);
    final img = await decodeImageFromList(data.buffer.asUint8List());
    _sheets[asset] = img;
    return img;
  }

  static Future<void> warmAll() => Future.wait(
        PetCharacters.all
            .expand((p) => [load(p.spriteAsset), load(p.walkAsset)]),
        eagerError: false,
      ).then((_) {});
}
