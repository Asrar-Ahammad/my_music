import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/sound_capsule_repository.dart';
import '../../domain/models/sound_capsule_stats.dart';

/// State for the Sound Capsule provider.
class SoundCapsuleState {
  final SoundCapsuleStats? stats;
  final bool isLoading;
  final String? error;
  final CapsulePeriod selectedPeriod;
  final DateTime selectedDate; // month or week start
  final List<DateTime> availableMonths;

  const SoundCapsuleState({
    this.stats,
    this.isLoading = false,
    this.error,
    required this.selectedPeriod,
    required this.selectedDate,
    this.availableMonths = const [],
  });

  SoundCapsuleState copyWith({
    SoundCapsuleStats? stats,
    bool? isLoading,
    String? error,
    CapsulePeriod? selectedPeriod,
    DateTime? selectedDate,
    List<DateTime>? availableMonths,
  }) {
    return SoundCapsuleState(
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      selectedDate: selectedDate ?? this.selectedDate,
      availableMonths: availableMonths ?? this.availableMonths,
    );
  }
}

/// Riverpod notifier that drives the Sound Capsule screen.
/// Stats computation is offloaded via [Future] to keep the UI responsive.
class SoundCapsuleNotifier extends Notifier<SoundCapsuleState> {
  late final SoundCapsuleRepository _repo;

  @override
  SoundCapsuleState build() {
    _repo = SoundCapsuleRepository();
    final now = DateTime.now();
    // Load current month on startup (no await here; call loadStats explicitly)
    Future.microtask(loadStats);
    return SoundCapsuleState(
      selectedPeriod: CapsulePeriod.monthly,
      selectedDate: DateTime(now.year, now.month),
    );
  }

  // ── Public actions ─────────────────────────────────────────────────────────

  Future<void> loadStats() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final months = await Future(() => _repo.getAvailableMonths());
      final stats = await Future(() => _computeStats());
      state = state.copyWith(
        isLoading: false,
        stats: stats,
        availableMonths: months,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load stats: $e',
      );
    }
  }

  Future<void> switchPeriod(CapsulePeriod period) async {
    if (state.selectedPeriod == period) return;
    state = state.copyWith(selectedPeriod: period);
    await loadStats();
  }

  Future<void> selectMonth(DateTime month) async {
    state = state.copyWith(
      selectedPeriod: CapsulePeriod.monthly,
      selectedDate: DateTime(month.year, month.month),
    );
    await loadStats();
  }

  Future<void> selectWeek(DateTime weekStart) async {
    state = state.copyWith(
      selectedPeriod: CapsulePeriod.weekly,
      selectedDate: weekStart,
    );
    await loadStats();
  }

  void goToPreviousPeriod() {
    final current = state.selectedDate;
    if (state.selectedPeriod == CapsulePeriod.monthly) {
      selectMonth(DateTime(current.year, current.month - 1));
    } else {
      selectWeek(current.subtract(const Duration(days: 7)));
    }
  }

  void goToNextPeriod() {
    final now = DateTime.now();
    final current = state.selectedDate;
    if (state.selectedPeriod == CapsulePeriod.monthly) {
      final next = DateTime(current.year, current.month + 1);
      if (next.isBefore(DateTime(now.year, now.month + 1))) {
        selectMonth(next);
      }
    } else {
      final next = current.add(const Duration(days: 7));
      if (next.isBefore(now)) selectWeek(next);
    }
  }

  bool get canGoNext {
    final now = DateTime.now();
    final current = state.selectedDate;
    if (state.selectedPeriod == CapsulePeriod.monthly) {
      return current.year < now.year ||
          (current.year == now.year && current.month < now.month);
    }
    return current.add(const Duration(days: 7)).isBefore(now);
  }

  // ── Private ────────────────────────────────────────────────────────────────

  SoundCapsuleStats _computeStats() {
    final date = state.selectedDate;
    if (state.selectedPeriod == CapsulePeriod.monthly) {
      return _repo.getMonthlyStats(date.year, date.month);
    } else {
      return _repo.getWeeklyStats(date);
    }
  }
}

// ── Providers ──────────────────────────────────────────────────────────────

final soundCapsuleProvider =
    NotifierProvider<SoundCapsuleNotifier, SoundCapsuleState>(
  SoundCapsuleNotifier.new,
);
