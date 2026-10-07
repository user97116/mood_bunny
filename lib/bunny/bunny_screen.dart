import 'dart:io';

import 'package:flutter/material.dart';

import 'bunny_host.dart';
import 'bunny_scheduler.dart';
import 'desktop_pet.dart';
import 'mood_entry.dart';
import 'pet_character.dart';

/// Settings + history UI for the mood bunny.
///
/// The bunny itself is shown by [BunnyHost] as a Flutter [OverlayEntry],
/// so it can appear over any route — not just this screen.
class BunnyScreen extends StatelessWidget {
  const BunnyScreen({super.key});

  String _countdownText(DateTime? next, BunnyConfig config) {
    if (next == null) return '-';
    final diff = next.difference(DateTime.now());
    if (diff.isNegative) return 'soon...';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (config.useCustomInterval && h == 0 && m < 2) return '${diff.inSeconds}s';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _fmtTime(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.month}/${d.day} $hh:$mm';
  }

  static String _hh(int h) => h.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final host = BunnyHost.of(context);
    if (host == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mood Bunny')),
        body: const Center(
          child: Text('Wrap your app with BunnyHost to enable the bunny.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mood Bunny')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card
          ValueListenableBuilder<bool>(
            valueListenable: host.bunnyVisible,
            builder: (_, visible, _) => ValueListenableBuilder<DateTime?>(
              valueListenable: host.nextVisit,
              builder: (_, next, _) => ValueListenableBuilder<BunnyConfig>(
                valueListenable: host.config,
                builder: (_, cfg, _) => Card(
                  child: ListTile(
                    leading:
                        const Text(':)', style: TextStyle(fontSize: 32)),
                    title: Text(visible
                        ? 'Bunny is here! Say hi!'
                        : 'Next visit in ${_countdownText(next, cfg)}'),
                    subtitle: Text(cfg.useCustomInterval
                        ? 'Every ${cfg.intervalMinutes} min'
                        : '${cfg.visitsPerDay}x per day, ${_hh(cfg.startHour)}:00-${_hh(cfg.endHour)}:00 random'),
                    trailing: FilledButton(
                      onPressed: host.summonNow,
                      child: const Text('Summon'),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Schedule settings
          ValueListenableBuilder<BunnyConfig>(
            valueListenable: host.config,
            builder: (_, cfg, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Visit schedule',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Pet'),
                    const SizedBox(height: 4),
                    PetPicker(
                      selectedId: cfg.pet,
                      onSelected: (id) =>
                          host.saveConfig(cfg.copyWith(pet: id)),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Custom interval'),
                      subtitle: const Text(
                          'Off = 3-5 random times per day. On = fixed minutes.'),
                      value: cfg.useCustomInterval,
                      onChanged: (v) => host.saveConfig(
                          cfg.copyWith(useCustomInterval: v)),
                    ),
                    if (!cfg.useCustomInterval) ...[
                      Text('Visits per day: ${cfg.visitsPerDay}'),
                      Slider(
                        min: 1,
                        max: 8,
                        divisions: 7,
                        value: cfg.visitsPerDay.toDouble(),
                        label: '${cfg.visitsPerDay}',
                        onChanged: (v) => host.saveConfig(
                            cfg.copyWith(visitsPerDay: v.round())),
                      ),
                      Text(
                          'Active hours: ${_hh(cfg.startHour)}:00 - ${_hh(cfg.endHour)}:00'),
                      RangeSlider(
                        min: 0,
                        max: 24,
                        divisions: 24,
                        values: RangeValues(cfg.startHour.toDouble(),
                            cfg.endHour.toDouble()),
                        labels: RangeLabels('${cfg.startHour}:00',
                            '${cfg.endHour}:00'),
                        onChanged: (v) {
                          final s = v.start.round().clamp(0, 23);
                          var e = v.end.round().clamp(1, 24);
                          if (e <= s) e = s + 1;
                          host.saveConfig(
                              cfg.copyWith(startHour: s, endHour: e));
                        },
                      ),
                      const Text(
                        'Bunny appears at random times inside the active hours, '
                        'slides in from the entry side, asks your mood, '
                        'reacts, then hops back and disappears.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ] else ...[
                      Text('Every ${cfg.intervalMinutes} minutes'),
                      Slider(
                        min: 15,
                        max: 240,
                        divisions: 15,
                        value: cfg.intervalMinutes.toDouble(),
                        label: '${cfg.intervalMinutes}m',
                        onChanged: (v) => host.saveConfig(
                            cfg.copyWith(intervalMinutes: v.round())),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text('Entry side'),
                    const SizedBox(height: 4),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'random', label: Text('Random')),
                        ButtonSegment(value: 'left', label: Text('Left')),
                        ButtonSegment(value: 'right', label: Text('Right')),
                      ],
                      selected: {cfg.side},
                      onSelectionChanged: (s) =>
                          host.saveConfig(cfg.copyWith(side: s.first)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'Leaves on its own after ${cfg.autoHideSeconds}s if ignored'),
                    Slider(
                      min: 15,
                      max: 180,
                      divisions: 11,
                      value: cfg.autoHideSeconds.toDouble().clamp(15, 180),
                      label: '${cfg.autoHideSeconds}s',
                      onChanged: (v) => host.saveConfig(
                          cfg.copyWith(autoHideSeconds: v.round())),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // History
          ValueListenableBuilder<List<MoodEntry>>(
            valueListenable: host.history,
            builder: (_, items, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('History (${items.length})',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton(
                          onPressed: items.isEmpty ? null : host.clearHistory,
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No check-ins yet. Tap Summon to log your first mood!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      for (final e in items.take(30))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Text(
                            BunnyMoods.byId(e.mood).emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text(BunnyMoods.byId(e.mood).label),
                          trailing: Text(_fmtTime(e.at),
                              style: const TextStyle(color: Colors.grey)),
                        ),
                  ],
                ),
              ),
            ),
          ),
          if (Platform.isWindows) const SizedBox(height: 12),
          if (Platform.isWindows) const _DesktopPetCard(),
        ],
      ),
    );
  }
}

/// Desktop pet controls: transparent always-on-top window + tray +
/// autostart, so the bunny appears on the desktop even when the main
/// app window is closed. (The in-app overlay above dies with the app.)
class _DesktopPetCard extends StatefulWidget {
  const _DesktopPetCard();

  @override
  State<_DesktopPetCard> createState() => _DesktopPetCardState();
}

class _DesktopPetCardState extends State<_DesktopPetCard> {
  bool? _autostart;

  @override
  void initState() {
    super.initState();
    DesktopPetAutostart.isEnabled().then((v) {
      if (mounted) setState(() => _autostart = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Desktop pet (shows when app is closed)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Runs the same schedule as a full-screen transparent overlay. '
              'It stays hidden when idle, pops up on visits, '
              'and can start with Windows via the toggle.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start with Windows'),
              subtitle: const Text('Registers this exe with a --pet flag.'),
              value: _autostart ?? false,
              onChanged: _autostart == null
                  ? null
                  : (v) async {
                      setState(() => _autostart = v);
                      await DesktopPetAutostart.setEnabled(v);
                      if (mounted) {
                        setState(() {});
                      }
                    },
            ),
            const Text(
              'Preview: flutter run -d windows -t lib/pet_main.dart\n'
              'Install: flutter build windows, run the exe once, turn the toggle on.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

