import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'bunny_overlay.dart';
import 'bunny_scheduler.dart';
import 'mood_entry.dart';
import 'mood_store.dart';
import 'pet_character.dart';

/// True desktop-pet mode (Windows).
///
/// Unlike [BunnyHost]'s in-app Flutter overlay (which dies with the app),
/// this is a FULL-SCREEN transparent always-on-top window backed by a
/// background process:
/// - window is HIDDEN most of the day (invisible on desktop, zero clutter),
/// - [BunnyScheduler] wakes it 3-5x/day (or on your custom interval),
/// - bunny slides in from the left/right screen edge to the screen center,
///   asks mood, saves locally, reacts, slides back, window hides again,
/// - tray icon keeps the process alive with Summon/Quit,
/// - optional autostart so it survives reboots ("even app closed").
///
/// Wiring (same exe, two modes):
/// ```dart
/// void main(List<String> args) async {
///   WidgetsFlutterBinding.ensureInitialized();
///   if (isPetMode(args)) {
///     await runDesktopPet();
///     return;
///   }
///   runApp(const MyApp());
/// }
/// ```
/// Preview: `flutter run -d windows -t lib/pet_main.dart`
/// Install: `flutter build windows`, run the exe once, enable autostart
/// in settings (registers `<exe> --pet` at login).
bool isPetMode(List<String> args) => args.contains('--pet');

Future<void> runDesktopPet() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await windowManager.ensureInitialized();
    // Full-screen overlay: size the window to the primary display so the
    // bunny travels the whole screen edge -> center -> edge.
    Size full = const Size(1280, 720);
    try {
      final display = await screenRetriever.getPrimaryDisplay();
      full = display.size;
    } catch (_) {}
    final options = WindowOptions(
      size: full,
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: true,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'Mood Bunny',
      alwaysOnTop: true,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      await windowManager.setSize(full);
      await windowManager.center();
      await windowManager.setPreventClose(true);
      await windowManager.hide(); // start invisible; scheduler shows on visit
    });
  } catch (_) {
    // Not on desktop / plugin missing — pet mode makes no sense here.
    return;
  }
  runApp(const DesktopPetApp());
}

class DesktopPetApp extends StatefulWidget {
  const DesktopPetApp({super.key});

  @override
  State<DesktopPetApp> createState() => _DesktopPetAppState();
}

class _DesktopPetAppState extends State<DesktopPetApp>
    with WindowListener, TrayListener {
  final MoodStore _store = MoodStore();
  late final BunnyScheduler _scheduler;
  BunnyConfig _config = const BunnyConfig();
  String? _lastRaw;
  Timer? _configTimer;
  BunnySide _side = BunnySide.left;
  bool _showing = false;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    _scheduler = BunnyScheduler(onVisit: _onVisit);
    windowManager.addListener(this);
    _init();
  }

  Future<void> _init() async {
    // Warm sprite sheets so the first visit paints instantly.
    unawaited(PetSheetCache.warmAll().then((_) {}, onError: (_) {}));
    final prefs = await SharedPreferences.getInstance();
    _lastRaw = prefs.getString(MoodStore.configKey);
    _config = _loadConfig(_lastRaw);
    await _setupTray();
    _scheduler.start(_config);
    debugPrint('[Pet] scheduler started, next visit: ${_scheduler.nextVisit}');
    // Pick up settings changed in the main app without restarting the pet.
    _configTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(MoodStore.configKey);
        if (raw != _lastRaw) {
          _lastRaw = raw;
          _config = _loadConfig(raw);
          _scheduler.updateConfig(_config);
        }
      } catch (_) {}
    });
    if (mounted) setState(() {});
  }

  /// Reads JSON (current) or legacy pipe format, same as [BunnyHost].
  static BunnyConfig _loadConfig(String? raw) {
    if (raw == null || raw.isEmpty) return const BunnyConfig();
    try {
      final trimmed = raw.trim();
      if (trimmed.startsWith('{')) {
        return BunnyConfig.fromJson(
            Map<String, dynamic>.from(jsonDecode(trimmed) as Map));
      }
      final p = trimmed.split('|');
      return BunnyConfig(
        visitsPerDay: int.tryParse(p[0]) ?? 4,
        useCustomInterval: (p.length > 1 ? p[1] : 'false') == 'true',
        intervalMinutes: p.length > 2 ? int.tryParse(p[2]) ?? 120 : 120,
      );
    } catch (_) {
      return const BunnyConfig();
    }
  }

  Future<void> _setupTray() async {
    // Each step is independent: the menu must register even if the icon
    // file is missing, otherwise right-click shows nothing at all.
    // [Pet] logs go to `flutter run` console for diagnosing tray issues.
    try {
      final iconPath = await _trayIconPath();
      debugPrint(
          '[Pet] tray icon path: $iconPath exists=${await File(iconPath).exists()}');
      await trayManager.setIcon(iconPath);
      debugPrint('[Pet] tray icon set OK');
    } catch (e) {
      debugPrint('[Pet] tray icon FAILED: $e');
    }
    try {
      await trayManager.setToolTip('Mood Bunny');
    } catch (e) {
      debugPrint('[Pet] tooltip FAILED: $e');
    }
    try {
      await trayManager.setContextMenu(
        Menu(items: [
          MenuItem(key: 'summon', label: 'Summon bunny now'),
          MenuItem(key: 'settings', label: 'Configuration'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Quit'),
        ]),
      );
      debugPrint('[Pet] tray menu set OK (summon/settings/quit)');
    } catch (e) {
      debugPrint('[Pet] tray menu FAILED: $e');
    }
    try {
      trayManager.addListener(this);
    } catch (e) {
      debugPrint('[Pet] tray listener FAILED: $e');
    }
  }

  /// tray_manager needs a real file path, so unpack the bundled .ico once.
  Future<String> _trayIconPath() async {
    final target = File('${Directory.systemTemp.path}/bunny_tray.ico');
    if (!await target.exists()) {
      final data = await rootBundle.load('assets/tray_icon.ico');
      await target.writeAsBytes(data.buffer.asUint8List());
    }
    return target.path;
  }

  void _onVisit() {
    if (!mounted) return;
    setState(() {
      _side = _scheduler.nextSide;
      _showing = true;
      _showSettings = false; // a visit takes over the window
    });
    _showWindow();
  }

  Future<void> _showWindow() async {
    try {
      await windowManager.center();
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  Future<void> _onMood(String mood) async {
    await _store.add(MoodEntry(at: DateTime.now(), mood: mood));
  }

  void _onGone() {
    if (!mounted) return;
    setState(() => _showing = false);
    try {
      windowManager.hide();
    } catch (_) {}
  }

  // Close button (X) hides to tray instead of killing the pet.
  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() {
    _scheduler.summonNow(); // left-click tray icon = instant visit
  }

  @override
  void onTrayIconRightMouseDown() {
    // Windows does NOT auto-show the menu: pop it manually.
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    debugPrint('[Pet] tray menu clicked: ${menuItem.key}');
    switch (menuItem.key) {
      case 'summon':
        _scheduler.summonNow();
      case 'settings':
        _openSettings();
      case 'quit':
        _quit();
    }
  }

  /// Right-click tray -> Configuration: show the settings panel in the
  /// (fullscreen transparent) pet window.
  void _openSettings() {
    if (!mounted) return;
    setState(() {
      _showSettings = true;
      _showing = false;
    });
    _showWindow();
  }

  void _closeSettings() {
    if (!mounted) return;
    setState(() => _showSettings = false);
    try {
      windowManager.hide();
    } catch (_) {}
  }

  /// Save from the in-pet panel: same shared-prefs key the main app uses,
  /// applied to the running scheduler immediately.
  Future<void> _savePanelConfig(BunnyConfig c) async {
    setState(() => _config = c);
    _scheduler.updateConfig(c);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(MoodStore.configKey, jsonEncode(c.toJson()));
    } catch (_) {}
  }

  Future<void> _quit() async {
    _scheduler.stop();
    try {
      trayManager.removeListener(this);
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } catch (_) {}
    exit(0);
  }

  @override
  void dispose() {
    _configTimer?.cancel();
    _scheduler.stop();
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: _showing
            ? BunnyOverlay(
                side: _side,
                character: PetCharacters.byId(_config.pet),
                autoHideSeconds: _config.autoHideSeconds,
                onMoodSelected: _onMood,
                onGone: _onGone,
              )
            : _showSettings
                ? Center(
                    child: _PetSettingsPanel(
                      config: _config,
                      onChanged: _savePanelConfig,
                      onClose: _closeSettings,
                    ),
                  )
                : const SizedBox.shrink(),
      ),
    );
  }
}

/// Settings panel shown inside the pet window via tray -> Configuration.
/// Same options as the main app's settings screen, saved to the same
/// shared-prefs key so both stay in sync.
class _PetSettingsPanel extends StatelessWidget {
  final BunnyConfig config;
  final ValueChanged<BunnyConfig> onChanged;
  final void Function() onClose;

  const _PetSettingsPanel({
    required this.config,
    required this.onChanged,
    required this.onClose,
  });

  static String _hh(int h) => h.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final cfg = config;
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(blurRadius: 24, color: Colors.black26),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Bunny configuration',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Pet'),
            const SizedBox(height: 4),
            PetPicker(
              selectedId: cfg.pet,
              onSelected: (id) => onChanged(cfg.copyWith(pet: id)),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Custom interval'),
              subtitle: const Text('Off = random times per day.'),
              value: cfg.useCustomInterval,
              onChanged: (v) =>
                  onChanged(cfg.copyWith(useCustomInterval: v)),
            ),
            if (!cfg.useCustomInterval) ...[
              Text('Visits per day: ${cfg.visitsPerDay}'),
              Slider(
                min: 1,
                max: 8,
                divisions: 7,
                value: cfg.visitsPerDay.toDouble(),
                label: '${cfg.visitsPerDay}',
                onChanged: (v) =>
                    onChanged(cfg.copyWith(visitsPerDay: v.round())),
              ),
              Text(
                  'Active hours: ${_hh(cfg.startHour)}:00 - ${_hh(cfg.endHour)}:00'),
              RangeSlider(
                min: 0,
                max: 24,
                divisions: 24,
                values: RangeValues(cfg.startHour.toDouble(),
                    cfg.endHour.toDouble()),
                labels: RangeLabels(
                    '${cfg.startHour}:00', '${cfg.endHour}:00'),
                onChanged: (v) {
                  final s = v.start.round().clamp(0, 23);
                  var e = v.end.round().clamp(1, 24);
                  if (e <= s) e = s + 1;
                  onChanged(cfg.copyWith(startHour: s, endHour: e));
                },
              ),
            ] else ...[
              Text('Every ${cfg.intervalMinutes} minutes'),
              Slider(
                min: 15,
                max: 240,
                divisions: 15,
                value: cfg.intervalMinutes.toDouble(),
                label: '${cfg.intervalMinutes}m',
                onChanged: (v) =>
                    onChanged(cfg.copyWith(intervalMinutes: v.round())),
              ),
            ],
            const SizedBox(height: 8),
            const Text('Entry side'),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'random', label: Text('Random')),
                ButtonSegment(value: 'left', label: Text('Left')),
                ButtonSegment(value: 'right', label: Text('Right')),
              ],
              selected: {cfg.side},
              onSelectionChanged: (s) =>
                  onChanged(cfg.copyWith(side: s.first)),
            ),
            const SizedBox(height: 8),
            Text('Leaves on its own after ${cfg.autoHideSeconds}s'),
            Slider(
              min: 15,
              max: 180,
              divisions: 11,
              value: cfg.autoHideSeconds.toDouble().clamp(15, 180),
              label: '${cfg.autoHideSeconds}s',
              onChanged: (v) =>
                  onChanged(cfg.copyWith(autoHideSeconds: v.round())),
            ),
          ],
        ),
      ),
    );
  }
}

/// Autostart switch backing store for the settings UI.
/// Registers `<exe> --pet` in the Windows Run key on [setEnabled](true).
class DesktopPetAutostart {
  static Future<void> _setup() async {
    if (!Platform.isWindows) return;
    launchAtStartup.setup(
      appName: 'MoodBunnyPet',
      appPath: Platform.resolvedExecutable,
      args: <String>['--pet'],
    );
  }

  static Future<bool> isEnabled() async {
    try {
      return await launchAtStartup.isEnabled();
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool value) async {
    try {
      await _setup();
      if (value) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
    } catch (_) {}
  }
}
