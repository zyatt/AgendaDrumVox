// lib/providers/show_provider.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/show_model.dart';
import '../services/supabase_service.dart';

class ShowsNotifier extends AsyncNotifier<List<ShowModel>> {
  RealtimeChannel? _channel;

  @override
  Future<List<ShowModel>> build() async {
    final shows = await SupabaseService.fetchAllShows();
    _subscribeRealtime();
    ref.onDispose(() => _channel?.unsubscribe());
    return shows;
  }

  void _subscribeRealtime() {
    _channel = Supabase.instance.client
        .channel('shows_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shows',
          callback: (payload) async {
            final updated = await SupabaseService.fetchAllShows();
            state = AsyncData(updated);
          },
        )
        .subscribe();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => SupabaseService.fetchAllShows());
  }

  Future<void> addShow(ShowModel show) async {
    final token = await FirebaseMessaging.instance.getToken();
    await SupabaseService.createShow(show, deviceToken: token);
  }

  Future<void> updateShow(ShowModel show) async {
    await SupabaseService.updateShow(show);
  }

  Future<void> deleteShow(String showId) async {
    await SupabaseService.deleteShow(showId);
  }
}

final showsProvider = AsyncNotifierProvider<ShowsNotifier, List<ShowModel>>(
  ShowsNotifier.new,
);

final selectedDateProvider = StateProvider<DateTime>(
  (ref) => DateTime.now(),
);

final showsBySelectedDateProvider = Provider<List<ShowModel>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final showsAsync = ref.watch(showsProvider);

  return showsAsync.whenOrNull(data: (shows) {
    return shows.where((show) {
      return show.showDate.year == selectedDate.year &&
          show.showDate.month == selectedDate.month &&
          show.showDate.day == selectedDate.day;
    }).toList();
  }) ?? [];
});

final showDatesProvider = Provider<Set<DateTime>>((ref) {
  final showsAsync = ref.watch(showsProvider);

  return showsAsync.whenOrNull(data: (shows) {
    return shows.map((s) => DateTime(
      s.showDate.year, s.showDate.month, s.showDate.day,
    )).toSet();
  }) ?? {};
});

final selectedMonthProvider = StateProvider<DateTime>(
  (ref) => DateTime.now(),
);

final monthlyStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final month = ref.watch(selectedMonthProvider);
  ref.watch(showsProvider);
  return await SupabaseService.getMonthlyStats(month.year, month.month);
});