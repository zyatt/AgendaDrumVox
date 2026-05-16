import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/show_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const String _fixedUserId = '00000000-0000-0000-0000-000000000001';
final supabaseUrl = dotenv.env['SUPABASE_URL'];

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<List<ShowModel>> fetchAllShows() async {
    final response = await _client
        .from('shows')
        .select()
        .eq('user_id', _fixedUserId)
        .order('show_date', ascending: true);

    return (response as List).map((e) => ShowModel.fromMap(e)).toList();
  }

  static Future<List<ShowModel>> fetchShowsByMonth(int year, int month) async {
    final start = DateTime(year, month, 1).toIso8601String().split('T').first;
    final end = DateTime(year, month + 1, 0).toIso8601String().split('T').first;

    final response = await _client
        .from('shows')
        .select()
        .eq('user_id', _fixedUserId)
        .gte('show_date', start)
        .lte('show_date', end)
        .order('show_date', ascending: true);

    return (response as List).map((e) => ShowModel.fromMap(e)).toList();
  }

  static Future<ShowModel> createShow(
    ShowModel show, {
    String? deviceToken,
    String? deviceId,
  }) async {
    final data = show.toMap();
    data['user_id'] = _fixedUserId;
    if (deviceToken != null) data['created_by_token'] = deviceToken;
    if (deviceId != null) data['created_by_device_id'] = deviceId;

    final response = await _client
        .from('shows')
        .insert(data)
        .select()
        .single();

    return ShowModel.fromMap(response);
  }

  static Future<ShowModel> updateShow(ShowModel show) async {
    final response = await _client
        .from('shows')
        .update(show.toMap())
        .eq('id', show.id)
        .select()
        .single();

    return ShowModel.fromMap(response);
  }

  static Future<ShowModel> cancelShow(
    ShowModel show, {
    String? deviceToken,
    String? deviceId,
  }) async {
    final data = <String, dynamic>{
      'cancelled': true,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (deviceToken != null) data['cancelled_by_token'] = deviceToken;
    if (deviceId != null) data['cancelled_by_device_id'] = deviceId;

    final response = await _client
        .from('shows')
        .update(data)
        .eq('id', show.id)
        .select()
        .single();

    return ShowModel.fromMap(response);
  }

  static Future<ShowModel> uncancelShow(ShowModel show) async {
    final data = <String, dynamic>{
      'cancelled': false,
      'cancelled_by_token': null,
      'cancelled_by_device_id': null,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('shows')
        .update(data)
        .eq('id', show.id)
        .select()
        .single();

    return ShowModel.fromMap(response);
  }

  static Future<void> deleteShow(String showId) async {
    await _client.from('shows').delete().eq('id', showId);
  }

  static Future<Map<String, dynamic>> getMonthlyStats(int year, int month) async {
    final shows = await fetchShowsByMonth(year, month);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final activeShows = shows.where((s) => !s.cancelled).toList();
    final cancelledShows = shows.where((s) => s.cancelled).toList();

    final totalEarnings = activeShows.fold<double>(0, (sum, s) => sum + s.value);

    final received = activeShows
        .where((s) {
          final d = DateTime(s.showDate.year, s.showDate.month, s.showDate.day);
          return d.isBefore(today);
        })
        .fold<double>(0, (sum, s) => sum + s.value);

    final pending = activeShows
        .where((s) {
          final d = DateTime(s.showDate.year, s.showDate.month, s.showDate.day);
          return !d.isBefore(today);
        })
        .fold<double>(0, (sum, s) => sum + s.value);

    final cancelled = cancelledShows.fold<double>(0, (sum, s) => sum + s.value);

    return {
      'total_shows': activeShows.length,
      'total_earnings': totalEarnings,
      'received': received,
      'pending': pending,
      'cancelled': cancelled,
      'cancelled_count': cancelledShows.length,
      'shows': shows,
    };
  }

  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final start = DateTime.now();
      await _client.from('shows').select('id').limit(1);
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      return {
        'success': true,
        'message': 'Conexão OK',
        'latency_ms': elapsed,
        'url': supabaseUrl,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
        'latency_ms': null,
        'url': supabaseUrl,
      };
    }
  }

  static Future<void> saveFcmToken(String token, {required String deviceId}) async {
    await _client.from('fcm_tokens').upsert({
      'device_id': deviceId,
      'token': token,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'device_id');
  }
}