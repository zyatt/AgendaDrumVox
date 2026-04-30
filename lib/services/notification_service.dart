import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/formatters.dart';
import '../models/show_model.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
    );

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.requestNotificationsPermission();
  }

  static Future<void> showNewShowNotification(ShowModel show) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'new_show_channel',
        'Novas Datas',
        channelDescription: 'Notificações quando uma nova data é agendada',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _plugin.show(
      show.hashCode,
      'Nova data agendada!',
      '${show.local} · ${AppFormatters.relativeDate(show.showDate)} · ${AppFormatters.currency(show.value)}',
      details,
    );
  }
}