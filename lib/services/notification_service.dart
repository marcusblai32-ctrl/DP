import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Notifications de rappel avec son (Android). Sur Windows, les rappels sont
/// signalés dans l'application (voir `_checkDueReminders` dans main.dart).
class NotificationService {
  const NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const String channelId = 'dp_reminders_sound';
  static const String channelName = 'Rappels de cours';
  static const String channelDescription = 'Rappels de cours et de tâches avec son et vibration.';

  /// Notifications système prises en charge sur cette plateforme.
  static bool get supported => !kIsWeb && Platform.isAndroid;

  /// Identifiant stable (le hashCode d'une String n'est pas garanti stable).
  static int notifId(Map<String, dynamic> reminder) {
    var h = 7;
    for (final c in '${reminder['id']}'.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  /// Heure de déclenchement : date + heure du rappel moins l'avance choisie.
  static DateTime? dueTime(Map<String, dynamic> reminder) {
    final date = DateTime.tryParse('${reminder['date'] ?? ''}');
    if (date == null) return null;
    var hour = 9, minute = 0;
    final parts = '${reminder['time'] ?? ''}'.split(':');
    if (parts.length >= 2) {
      hour = int.tryParse(parts[0].trim()) ?? 9;
      minute = int.tryParse(parts[1].trim()) ?? 0;
    }
    final lead = (reminder['lead'] as num?)?.toInt() ?? 0;
    return DateTime(date.year, date.month, date.day, hour, minute).subtract(Duration(minutes: lead));
  }

  static NotificationDetails _details() => NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.reminder,
        ),
      );

  static Future<void> init() async {
    if (!supported || _ready) return;
    try {
      tzdata.initializeTimeZones();
      const settings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
      await _plugin.initialize(settings);
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ));
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Demande l'autorisation d'afficher des notifications (Android 13 et plus).
  static Future<bool> requestPermission() async {
    if (!supported) return false;
    await init();
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> schedule(Map<String, dynamic> reminder) async {
    if (!supported) return;
    await init();
    if (!_ready || reminder['done'] == true) return;
    final due = dueTime(reminder);
    if (due == null || !due.isAfter(DateTime.now().add(const Duration(seconds: 2)))) return;
    final when = tz.TZDateTime.from(due, tz.UTC);
    final title = 'Rappel DP';
    final body = '${reminder['title'] ?? 'Rappel'} · ${reminder['time'] ?? ''}'.trim();

    Future<void> go(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          notifId(reminder),
          title,
          body,
          when,
          _details(),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );

    try {
      await go(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      try {
        await go(AndroidScheduleMode.inexactAllowWhileIdle);
      } catch (_) {}
    }
  }

  static Future<void> cancel(Map<String, dynamic> reminder) async {
    if (!supported) return;
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(notifId(reminder));
    } catch (_) {}
  }

  static Future<void> cancelAll() async {
    if (!supported) return;
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// Replanifie tous les rappels à venir (démarrage, import de sauvegarde).
  static Future<void> syncAll(List<Map<String, dynamic>> reminders) async {
    if (!supported) return;
    await init();
    if (!_ready) return;
    await cancelAll();
    for (final r in reminders) {
      await schedule(r);
    }
  }

  static Future<void> showNow(String title, String body) async {
    if (!supported) return;
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(0, title, body, _details());
    } catch (_) {}
  }
}
