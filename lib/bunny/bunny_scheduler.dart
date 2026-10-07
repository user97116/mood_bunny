import 'dart:async';
import 'dart:math';

/// User-tunable schedule.
class BunnyConfig {
  /// 3-5 times per day by default.
  final int visitsPerDay;
  /// If true, ignore [visitsPerDay] and use a fixed interval instead.
  final bool useCustomInterval;
  /// Minutes between visits when [useCustomInterval] is true.
  final int intervalMinutes;
  /// Active window (local time) for random daily visits.
  final int startHour;
  final int endHour;
  /// Seconds before the bunny gives up and leaves on its own.
  final int autoHideSeconds;
  /// Which screen edge the bunny enters from: 'random', 'left' or 'right'.
  final String side;
  /// Which pet visits: 'bunny', 'cat' or 'dog'.
  final String pet;

  const BunnyConfig({
    this.visitsPerDay = 4,
    this.useCustomInterval = false,
    this.intervalMinutes = 120,
    this.startHour = 9,
    this.endHour = 22,
    this.autoHideSeconds = 60,
    this.side = 'random',
    this.pet = 'bunny',
  });

  BunnyConfig copyWith({
    int? visitsPerDay,
    bool? useCustomInterval,
    int? intervalMinutes,
    int? startHour,
    int? endHour,
    int? autoHideSeconds,
    String? side,
    String? pet,
  }) {
    return BunnyConfig(
      visitsPerDay: visitsPerDay ?? this.visitsPerDay,
      useCustomInterval: useCustomInterval ?? this.useCustomInterval,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      startHour: startHour ?? this.startHour,
      endHour: endHour ?? this.endHour,
      autoHideSeconds: autoHideSeconds ?? this.autoHideSeconds,
      side: side ?? this.side,
      pet: pet ?? this.pet,
    );
  }

  Map<String, dynamic> toJson() => {
        'visitsPerDay': visitsPerDay,
        'useCustomInterval': useCustomInterval,
        'intervalMinutes': intervalMinutes,
        'startHour': startHour,
        'endHour': endHour,
        'autoHideSeconds': autoHideSeconds,
        'side': side,
        'pet': pet,
      };

  factory BunnyConfig.fromJson(Map<String, dynamic> json) {
    return BunnyConfig(
      visitsPerDay: (json['visitsPerDay'] as num?)?.toInt() ?? 4,
      useCustomInterval: json['useCustomInterval'] as bool? ?? false,
      intervalMinutes: (json['intervalMinutes'] as num?)?.toInt() ?? 120,
      startHour: (json['startHour'] as num?)?.toInt() ?? 9,
      endHour: (json['endHour'] as num?)?.toInt() ?? 22,
      autoHideSeconds: (json['autoHideSeconds'] as num?)?.toInt() ?? 60,
      side: json['side'] as String? ?? 'random',
      pet: json['pet'] as String? ?? 'bunny',
    );
  }
}

/// Pure helpers — easy to unit test.
class BunnySchedule {
  /// Random [count] visit times spread across [day]'s active window.
  /// Sorted ascending. Pure function for tests.
  static List<DateTime> planDayVisits({
    required DateTime day,
    required int count,
    int startHour = 9,
    int endHour = 22,
    Random? random,
  }) {
    final rnd = random ?? Random();
    final n = count.clamp(1, 10);
    final start = DateTime(day.year, day.month, day.day, startHour);
    final end = DateTime(day.year, day.month, day.day, endHour);
    final span = end.difference(start);
    if (span.inMinutes <= n) {
      return List.generate(
          n, (i) => start.add(Duration(minutes: i * (span.inMinutes ~/ n))));
    }
    // Split the day into n slots, pick one random moment per slot.
    // This guarantees even spread instead of clumping.
    final slot = span ~/ n;
    final visits = <DateTime>[];
    for (var i = 0; i < n; i++) {
      final slotStart = start.add(slot * i);
      final jitter = Duration(
        minutes: rnd.nextInt(slot.inMinutes.clamp(1, 1000000)),
      );
      visits.add(slotStart.add(jitter));
    }
    visits.sort();
    return visits;
  }

  /// Next visit strictly after [now] from today's plan, or null if done.
  static DateTime? nextVisitAfter(DateTime now, List<DateTime> todaysPlan) {
    for (final v in todaysPlan) {
      if (v.isAfter(now)) return v;
    }
    return null;
  }
}

enum BunnySide { left, right }

/// Ticks and fires [onVisit] when it's time for the bunny to appear.
///
/// - Daily mode: fires [visitsPerDay] random times inside active hours.
/// - Custom mode: fires every [intervalMinutes].
class BunnyScheduler {
  BunnyScheduler({required this.onVisit, Random? random})
      : _random = random ?? Random();

  final VoidCallback onVisit;
  final Random _random;

  BunnyConfig config = const BunnyConfig();
  List<DateTime> _todaysPlan = [];
  DateTime? _nextCustom;
  DateTime? nextVisit;
  BunnySide nextSide = BunnySide.left;
  Timer? _timer;
  DateTime _planDay = DateTime(2000);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void updateConfig(BunnyConfig c, {DateTime? now}) {
    config = c;
    _replan(now ?? DateTime.now());
  }

  void start(BunnyConfig c) {
    stop();
    updateConfig(c);
    // Check often enough to feel "random", cheap enough for desktop.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
    _tick();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Honors config.side ('left'/'right') or picks randomly.
  BunnySide _pickSide() {
    switch (config.side) {
      case 'left':
        return BunnySide.left;
      case 'right':
        return BunnySide.right;
      default:
        return _random.nextBool() ? BunnySide.left : BunnySide.right;
    }
  }

  /// Force an immediate visit (also re-picks the entry side).
  void summonNow() {
    nextSide = _pickSide();
    onVisit();
    if (config.useCustomInterval) {
      _nextCustom = DateTime.now().add(Duration(minutes: config.intervalMinutes));
      nextVisit = _nextCustom;
    } else {
      // Drop past visits so we don't double-fire.
      final now = DateTime.now();
      _todaysPlan = _todaysPlan.where((v) => v.isAfter(now)).toList();
      nextVisit = BunnySchedule.nextVisitAfter(now, _todaysPlan);
    }
  }

  void _replan(DateTime now) {
    if (config.useCustomInterval) {
      _nextCustom ??= now.add(Duration(minutes: config.intervalMinutes));
      nextVisit = _nextCustom;
    } else {
      if (!_isSameDay(_planDay, now) || _todaysPlan.isEmpty) {
        _planDay = now;
        _todaysPlan = BunnySchedule.planDayVisits(
          day: now,
          count: config.visitsPerDay,
          startHour: config.startHour,
          endHour: config.endHour,
          random: _random,
        );
        // If it's already late in the day, drop past times.
        _todaysPlan = _todaysPlan.where((v) => v.isAfter(now)).toList();
      }
      nextVisit = BunnySchedule.nextVisitAfter(now, _todaysPlan);
      // Day is over -> plan tomorrow (timer will pick it up, but pre-compute).
      if (nextVisit == null) {
        final tomorrow = now.add(const Duration(days: 1));
        _planDay = tomorrow;
        _todaysPlan = BunnySchedule.planDayVisits(
          day: tomorrow,
          count: config.visitsPerDay,
          startHour: config.startHour,
          endHour: config.endHour,
          random: _random,
        );
        nextVisit = _todaysPlan.first;
      }
    }
    nextSide = _pickSide();
  }

  void _tick() {
    final now = DateTime.now();
    if (config.useCustomInterval) {
      if (_nextCustom == null || !now.isBefore(_nextCustom!)) {
        nextSide = _pickSide();
        onVisit();
        _nextCustom = now.add(Duration(minutes: config.intervalMinutes));
        nextVisit = _nextCustom;
      }
    } else {
      if (!_isSameDay(_planDay, now)) {
        _replan(now);
      }
      final due = _todaysPlan.where((v) => !v.isAfter(now)).toList();
      if (due.isNotEmpty) {
        _todaysPlan = _todaysPlan.where((v) => v.isAfter(now)).toList();
        nextSide = _pickSide();
        onVisit();
        nextVisit = BunnySchedule.nextVisitAfter(now, _todaysPlan);
        if (nextVisit == null) _replan(now); // roll to tomorrow
      }
    }
  }
}

typedef VoidCallback = void Function();
