/// A single mood check-in recorded by the bunny.
class MoodEntry {
  final DateTime at;
  final String mood; // happy | okay | sad | stressed | tired | skipped
  final String? note;

  const MoodEntry({required this.at, required this.mood, this.note});

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'mood': mood,
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    return MoodEntry(
      at: DateTime.parse(json['at'] as String),
      mood: json['mood'] as String,
      note: json['note'] as String?,
    );
  }
}

/// All moods the bunny can ask about.
class BunnyMoods {
  static const List<BunnyMood> all = [
    BunnyMood(id: 'happy', emoji: '😊', label: 'Happy'),
    BunnyMood(id: 'okay', emoji: '😐', label: 'Okay'),
    BunnyMood(id: 'sad', emoji: '😔', label: 'Sad'),
    BunnyMood(id: 'stressed', emoji: '😠', label: 'Stressed'),
    BunnyMood(id: 'tired', emoji: '😴', label: 'Tired'),
  ];

  static BunnyMood byId(String id) =>
      all.firstWhere((m) => m.id == id, orElse: () => all[1]);
}

class BunnyMood {
  final String id;
  final String emoji;
  final String label;
  const BunnyMood({required this.id, required this.emoji, required this.label});
}
