import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/models/listening_event.dart';

/// Hive-backed service that persists and queries listening history
/// for the Sound Capsule analytics feature.
class ListeningHistoryService {
  static final ListeningHistoryService _instance =
      ListeningHistoryService._internal();
  factory ListeningHistoryService() => _instance;
  ListeningHistoryService._internal();

  Box? _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      _box = await Hive.openBox(AppConstants.listeningHistoryBox);
      _initialized = true;
    } catch (e) {
      debugPrint('ListeningHistoryService init error: $e');
    }
  }

  Box? get _safeBox {
    if (!_initialized || _box == null || !(_box!.isOpen)) return null;
    return _box;
  }

  /// Records a listening event. Silently ignores if storage unavailable.
  Future<void> recordPlay(ListeningEvent event) async {
    final box = _safeBox;
    if (box == null) return;
    if (!event.countsAsPlay) return; // below threshold — don't count
    try {
      final key = '${event.timestamp.millisecondsSinceEpoch}_${event.songId}';
      await box.put(key, event.toMap());
    } catch (e) {
      debugPrint('ListeningHistoryService recordPlay error: $e');
    }
  }

  /// Returns all events within [start, end] inclusive.
  List<ListeningEvent> getEventsInRange(DateTime start, DateTime end) {
    final box = _safeBox;
    if (box == null) return [];
    try {
      final startMs = start.millisecondsSinceEpoch;
      final endMs = end.millisecondsSinceEpoch;
      final results = <ListeningEvent>[];
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw is! Map) continue;
        final ts = raw['timestamp'] as int?;
        if (ts == null) continue;
        if (ts >= startMs && ts <= endMs) {
          try {
            results.add(ListeningEvent.fromMap(raw));
          } catch (_) {}
        }
      }
      return results;
    } catch (e) {
      debugPrint('ListeningHistoryService getEventsInRange error: $e');
      return [];
    }
  }

  /// Returns all events ever stored.
  List<ListeningEvent> getAllEvents() {
    final box = _safeBox;
    if (box == null) return [];
    try {
      return box.values
          .whereType<Map>()
          .map((m) {
            try {
              return ListeningEvent.fromMap(m);
            } catch (_) {
              return null;
            }
          })
          .whereType<ListeningEvent>()
          .toList();
    } catch (e) {
      debugPrint('ListeningHistoryService getAllEvents error: $e');
      return [];
    }
  }

  /// Returns the distinct months (year+month) that have at least one event,
  /// sorted descending (most recent first).
  List<DateTime> getAvailableMonths() {
    final all = getAllEvents();
    final seen = <String, DateTime>{};
    for (final e in all) {
      final key = '${e.timestamp.year}-${e.timestamp.month}';
      seen[key] ??= DateTime(e.timestamp.year, e.timestamp.month);
    }
    final months = seen.values.toList()
      ..sort((a, b) => b.compareTo(a));
    return months;
  }

  /// Deletes events older than [retentionMonths] months.
  Future<void> pruneOldEvents({int retentionMonths = 12}) async {
    final box = _safeBox;
    if (box == null) return;
    try {
      final cutoff = DateTime.now()
          .subtract(Duration(days: retentionMonths * 30))
          .millisecondsSinceEpoch;
      final keysToDelete = <dynamic>[];
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw is! Map) {
          keysToDelete.add(key);
          continue;
        }
        final ts = raw['timestamp'] as int?;
        if (ts != null && ts < cutoff) {
          keysToDelete.add(key);
        }
      }
      await box.deleteAll(keysToDelete);
    } catch (e) {
      debugPrint('ListeningHistoryService pruneOldEvents error: $e');
    }
  }

  /// Total count of stored events.
  int get eventCount => _safeBox?.length ?? 0;
}
