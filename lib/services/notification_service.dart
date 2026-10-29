import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Rappels sonores (Android) : sonnent comme une alarme à l'heure prévue.
/// Sur Windows, les rappels sont signalés dans l'application (voir
/// `_checkDueReminders` dans main.dart).
class NotificationService {
  const NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool _askedExactAlarm = false;

  /// Dernière erreur rencontrée (affichée par « Tester le son »).
  static String? lastError;

  // Nouveau canal : les réglages d'un canal Android ne peuvent plus être modifiés
  // après sa création, il faut donc un nouvel identifiant pour activer l'alarme.
  static const String channelId = 'dp_alarm_reminders_v2';
  static const String oldChannelId = 'dp_reminders_sound';
  static const String channelName = 'Rappels (alarme)';
  static const String channelDescription = 'Rappels de cours : sonnent comme une alarme à l\'heure prévue.';
  static const String alarmSoundUri = 'content://settings/system/alarm_alert';

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

  static final Int64List _vibration = Int64List.fromList(<int>[0, 900, 400, 900, 400, 900]);

  static NotificationDetails _details() => NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          sound: const UriAndroidNotificationSound(alarmSoundUri),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
          vibrationPattern: _vibration,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          fullScreenIntent: true,
          // FLAG_INSISTENT : le son se répète jusqu'à ce que l'on ouvre ou ferme la notification.
          additionalFlags: Int32List.fromList(<int>[4]),
          // Arrêt automatique au bout d'une minute si personne ne répond.
          timeoutAfter: 60000,
          autoCancel: true,
        ),
      );

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> init() async {
    if (!supported || _ready) return;
    try {
      tzdata.initializeTimeZones();
      const settings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
      await _plugin.initialize(settings);
      final android = _android;
      try {
        await android?.deleteNotificationChannel(oldChannelId);
      } catch (_) {}
      await android?.createNotificationChannel(AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        sound: const UriAndroidNotificationSound(alarmSoundUri),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern: _vibration,
      ));
      _ready = true;
    } catch (e) {
      _ready = false;
      lastError = 'Initialisation impossible : $e';
    }
  }

  /// Demande les autorisations nécessaires : notifications (Android 13+) puis alarmes exactes.
  static Future<bool> requestPermission() async {
    if (!supported) return false;
    await init();
    if (!_ready) return false;
    try {
      final android = _android;
      final granted = await android?.requestNotificationsPermission();
      try {
        final canExact = await android?.canScheduleExactNotifications();
        if (canExact == false && !_askedExactAlarm) {
          _askedExactAlarm = true;
          await android?.requestExactAlarmsPermission();
        }
      } catch (_) {}
      return granted ?? true;
    } catch (e) {
      lastError = 'Autorisation impossible : $e';
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
    const title = 'Rappel DP';
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
    } catch (e) {
      lastError = 'Alarme exacte refusée ($e), repli sur une alarme approximative.';
      try {
        await go(AndroidScheduleMode.inexactAllowWhileIdle);
      } catch (e2) {
        lastError = 'Planification impossible : $e2';
      }
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

  /// Affiche tout de suite une notification d'alarme (bouton « Tester le son »).
  static Future<bool> showNow(String title, String body) async {
    if (!supported) return false;
    await init();
    if (!_ready) return false;
    try {
      await _plugin.show(0, title, body, _details());
      return true;
    } catch (e) {
      lastError = 'Notification impossible : $e';
      return false;
    }
  }

  /// État des autorisations et des rappels planifiés, pour comprendre un silence.
  static Future<List<String>> diagnose() async {
    final lines = <String>[];
    if (!supported) {
      lines.add('Notifications système : disponibles sur Android seulement.');
      return lines;
    }
    await init();
    lines.add(_ready ? 'Service de notifications : prêt' : 'Service de notifications : NON initialisé');
    try {
      final enabled = await _android?.areNotificationsEnabled();
      lines.add('Notifications autorisées : ${enabled == null ? 'inconnu' : (enabled ? 'oui' : 'NON')}');
    } catch (_) {}
    try {
      final exact = await _android?.canScheduleExactNotifications();
      lines.add('Alarmes et rappels exacts : ${exact == null ? 'inconnu' : (exact ? 'oui' : 'NON')}');
    } catch (_) {}
    try {
      final pending = await _plugin.pendingNotificationRequests();
      lines.add('Rappels planifiés : ${pending.length}');
    } catch (_) {}
    if (lastError != null) lines.add('Dernière erreur : $lastError');
    return lines;
  }
}
