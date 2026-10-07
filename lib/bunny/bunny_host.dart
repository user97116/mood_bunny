import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bunny_overlay.dart';
import 'bunny_scheduler.dart';
import 'mood_entry.dart';
import 'mood_store.dart';
import 'pet_character.dart';

/// App-wide Flutter overlay host (no desktop plugins).
///
/// Wrap your app once and the bunny can pop up over ANY route:
///
/// ```dart
/// MaterialApp(
///   home: BunnyHost(child: MyHomePage()),
/// )
/// ```
///
/// Then anywhere below it:
///
/// ```dart
/// BunnyHost.of(context)?.summonNow();
/// ```
class BunnyHost extends StatefulWidget {
  final Widget child;
  final BunnyConfig initialConfig;

  const BunnyHost({
    super.key,
    required this.child,
    this.initialConfig = const BunnyConfig(visitsPerDay: 4),
  });

  static BunnyHostState? of(BuildContext context) =>
      context.findAncestorStateOfType<BunnyHostState>();

  @override
  State<BunnyHost> createState() => BunnyHostState();
}

class BunnyHostState extends State<BunnyHost> {
  final MoodStore store = MoodStore();
  late final BunnyScheduler scheduler;

  final ValueNotifier<BunnyConfig> config =
      ValueNotifier(const BunnyConfig(visitsPerDay: 4));
  final ValueNotifier<List<MoodEntry>> history = ValueNotifier(const []);
  final ValueNotifier<DateTime?> nextVisit = ValueNotifier(null);
  final ValueNotifier<bool> bunnyVisible = ValueNotifier(false);

  OverlayEntry? _entry;
  BunnySide _side = BunnySide.left;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    scheduler = BunnyScheduler(onVisit: _onVisitTime);
    config.value = widget.initialConfig;
    _init();
    _clock = Timer.periodic(const Duration(seconds: 10), (_) {
      nextVisit.value = scheduler.nextVisit;
    });
  }

  Future<void> _init() async {
    history.value = await store.load();
    // Warm sprite sheets so the first visit paints instantly.
    unawaited(PetSheetCache.warmAll().then((_) {}, onError: (_) {}));
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(MoodStore.configKey);
    if (raw != null) {
      try {
        config.value = BunnyConfig.fromJson(_decodeConfig(raw));
      } catch (_) {}
    }
    scheduler.start(config.value);
    nextVisit.value = scheduler.nextVisit;
  }

  /// Decodes stored config: current JSON format, legacy pipe format.
  Map<String, dynamic> _decodeConfig(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('{')) {
      try {
        return Map<String, dynamic>.from(
            jsonDecode(trimmed) as Map);
      } catch (_) {
        return {};
      }
    }
    final p = trimmed.split('|');
    return {
      'visitsPerDay': int.tryParse(p[0]) ?? 4,
      'useCustomInterval': (p.length > 1 ? p[1] : 'false') == 'true',
      'intervalMinutes': p.length > 2 ? int.tryParse(p[2]) ?? 120 : 120,
    };
  }

  Future<void> saveConfig(BunnyConfig c) async {
    config.value = c;
    scheduler.updateConfig(c);
    nextVisit.value = scheduler.nextVisit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(MoodStore.configKey, jsonEncode(c.toJson()));
  }

  Future<void> clearHistory() async {
    await store.clear();
    history.value = const [];
  }

  /// Show the bunny now via a root [OverlayEntry].
  /// Safe to call from any descendant context.
  void summonNow() {
    scheduler.summonNow();
    // summonNow() already fired onVisit -> _onVisitTime inserted the entry.
    // In case scheduler was busy, force-show:
    if (_entry == null) _onVisitTime();
  }

  void _onVisitTime() {
    if (!mounted) return;
    if (_entry != null) return; // already showing
    _side = scheduler.nextSide;
    bunnyVisible.value = true;
    nextVisit.value = scheduler.nextVisit;

    _entry = OverlayEntry(
      builder: (ctx) => Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.15),
          child: BunnyOverlay(
            side: _side,
            character: PetCharacters.byId(config.value.pet),
            autoHideSeconds: config.value.autoHideSeconds,
            onMoodSelected: _onMood,
            onGone: _onGone,
          ),
        ),
      ),
    );
    // Insert synchronously when possible (tap/timeout callbacks).
    // Fall back to post-frame when called during build/layout.
    void doInsert() {
      if (!mounted) return;
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay != null && _entry != null) {
        try {
          overlay.insert(_entry!);
        } catch (_) {
          // Likely called during build — retry after frame.
          WidgetsBinding.instance.addPostFrameCallback((_) => doInsert());
        }
      } else if (overlay == null) {
        // No Overlay above us (e.g. host placed above MaterialApp).
        // Fall back to inline display via setState.
        setState(() {});
      }
    }

    try {
      doInsert();
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => doInsert());
    }
  }

  Future<void> _onMood(String moodId) async {
    final updated =
        await store.add(MoodEntry(at: DateTime.now(), mood: moodId));
    history.value = List<MoodEntry>.unmodifiable(updated);
  }

  void _onGone() {
    try {
      _entry?.remove();
    } catch (_) {}
    _entry = null;
    if (mounted) {
      bunnyVisible.value = false;
      nextVisit.value = scheduler.nextVisit;
      // If host sits above MaterialApp there is no Overlay — repaint inline.
      setState(() {});
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    scheduler.stop();
    try {
      _entry?.remove();
    } catch (_) {}
    config.dispose();
    history.dispose();
    nextVisit.dispose();
    bunnyVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Inline fallback: if there is no Overlay ancestor (host above
    // MaterialApp), still render the bunny via Stack.
    final overlay = Overlay.maybeOf(context);
    final showInline = overlay == null && bunnyVisible.value;

    return Stack(
      children: [
        widget.child,
        if (showInline)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.15),
              child: ValueListenableBuilder<BunnyConfig>(
                valueListenable: config,
                builder: (_, cfg, _) => BunnyOverlay(
                  side: _side,
                  character: PetCharacters.byId(cfg.pet),
                  autoHideSeconds: cfg.autoHideSeconds,
                  onMoodSelected: _onMood,
                  onGone: _onGone,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
