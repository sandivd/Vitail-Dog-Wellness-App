import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Walk-reminder notifications. One stable notification ID with
/// cancel-then-schedule, so calling [scheduleWalkReminder] repeatedly is
/// always safe (idempotent re-scheduling).
class Notifications {
  Notifications._();

  static const int _kWalkReminderId = 1001;
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final Random _random = Random();
  static bool _ready = false;

  /// Call once at app start (before any scheduling).
  static Future<void> init() async {
    // Real device timezone (AEST/AEDT), so the daily repeat stays correct
    // across DST changes. Fall back to UTC if anything goes wrong.
    tzdata.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {}

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  /// Android 13+ silently drops notifications without this runtime grant.
  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Schedules the daily reminder at [hour]:[minute] local time, with a
  /// randomly-picked personalised message (dog name, goal, streak).
  static Future<void> scheduleWalkReminder(
      {required int hour, required int minute}) async {
    if (!_ready) return;
    await _plugin.cancel(id: _kWalkReminderId);

    final ctx = await _context();
    final name = ctx['name'] as String;
    final goal = ctx['goal'] as int;
    // The day they'd reach BY walking today: 0-day streak -> "Day 1".
    final streak = (ctx['streak'] as int) + 1;

    // One entry is picked per scheduling. We re-schedule on every app
    // launch, toggle and time change — so active users see variety across
    // days, while the message stays stable within a day.
    final messages = <(String, String)>[
      ('Day $streak with $name! 🔥', '$goal minutes keeps the streak alive.'),
      ("Today's goal: $goal min with $name",
          "You're one walk away from ticking it off."),
      ("$name's exercise prescription 💊",
          "$goal minutes. Doctor's orders."),
      ('$name is waiting by the door 🐕', 'Leash. Human. Now. Please.'),
      ("Woof! It's walk o'clock 🐾", '$name is ready. Are you?'),
      ('A tired dog is a happy dog 🐶', "Today's walk is ready when you are."),
      ('Free points are waiting outside 🎁',
          "Today's walk earns points toward your next reward."),
      ('Fresh air, happy tails 🌿',
          "Time for today's walk with $name"),
      ('$name + fresh air + points',
          "Everyone wins. Let's go."),
      ("$name's tail is wagging! 🐕",
          "You know exactly what that means."),
      ('Walk time with $name!',
          'Keep the streak alive. $goal minutes today.'),
    ];
    final (title, body) = messages[_random.nextInt(messages.length)];

    final now = tz.TZDateTime.now(tz.local);
    var when =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id: _kWalkReminderId,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'walk_reminders',
          'Walk reminders',
          channelDescription: 'A daily nudge to get out and walk',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      // Inexact on purpose: exact alarms need SCHEDULE_EXACT_ALARM
      // (denied-by-default on Android 14+). A few minutes' drift is fine
      // for a walk nudge.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Native daily repetition at the same wall-clock time.
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelWalkReminder() async {
    if (!_ready) return;
    await _plugin.cancel(id: _kWalkReminderId);
  }

  /// Best-effort fetch of the message context: dog name, daily goal and
  /// current streak. Falls back to neutral values when signed out or
  /// offline, so scheduling never fails on the copy.
  static Future<Map<String, dynamic>> _context() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return const {'name': 'your dog', 'goal': 30, 'streak': 0};

      final dog = await client
          .from('dogs')
          .select('dog_name, daily_goal_minutes')
          .eq('owner_id', userId)
          .limit(1)
          .maybeSingle();
      final profile = await client
          .from('profiles')
          .select('daily_streak')
          .eq('id', userId)
          .single();

      return {
        'name': (dog?['dog_name'] as String?) ?? 'your dog',
        'goal': (dog?['daily_goal_minutes'] as num?)?.toInt() ?? 30,
        'streak': (profile['daily_streak'] as num?)?.toInt() ?? 0,
      };
    } catch (_) {
      return const {'name': 'your dog', 'goal': 30, 'streak': 0};
    }
  }
}