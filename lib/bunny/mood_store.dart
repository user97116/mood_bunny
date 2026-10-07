import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'mood_entry.dart';

/// Local persistence for mood check-ins. SharedPreferences = stays on device.
class MoodStore {
  static const storageKey = 'bunny_moods_v1';
  static const configKey = 'bunny_config_v1';

  /// Decode helper (pure, testable without plugins).
  static List<MoodEntry> decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => MoodEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => b.at.compareTo(a.at));
    } catch (_) {
      return [];
    }
  }

  static String encode(List<MoodEntry> entries) =>
      jsonEncode(entries.map((e) => e.toJson()).toList());

  Future<List<MoodEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return decode(prefs.getString(storageKey));
  }

  Future<List<MoodEntry>> add(MoodEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final current = decode(prefs.getString(storageKey));
    current.insert(0, entry);
    // Keep it tiny: last 500 entries max.
    final trimmed = current.take(500).toList();
    await prefs.setString(storageKey, encode(trimmed));
    return trimmed;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}
