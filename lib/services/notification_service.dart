import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'base_service.dart';

// Fixed IDs for scheduled notifications so they can be cancelled/replaced
const _kStreakReminderId = 1001;
const _kGoalProgressId = 1002;

/// Notification service — local push notifications + Supabase persistence.
///
/// Notification types:
///   weekly_summary  — sent once per week (Tue+) on app open
///   streak_reminder — scheduled daily at 20:00 if no session today
///   goal_progress   — scheduled Sunday 18:00, weekly goal check
class NotificationService extends BaseService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ─── Initialization ──────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
    _initialized = true;
  }

  /// Request notification permissions (Android 13+, iOS).
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    } else if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  // ─── Show instant notification ─────────────────────────
  Future<void> _show(String title, String body,
      {int? id, String? payload}) async {
    const androidDetails = AndroidNotificationDetails(
      'hooplytics_main',
      'Hooplytics',
      channelDescription: 'Weekly summaries and reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    );
    const details =
        NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

    await _plugin.show(
      id: id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  // ─── Schedule repeating notification ───────────────────
  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'hooplytics_reminders',
      'Reminders',
      channelDescription: 'Streak and goal reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    );
    const details =
        NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleWeekly({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'hooplytics_reminders',
      'Reminders',
      channelDescription: 'Streak and goal reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    );
    const details =
        NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    // Advance to the target weekday
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  // ─── User prefs helpers ──────────────────────────────
  Map<String, dynamic> _userMeta() =>
      client.auth.currentUser?.userMetadata ?? {};

  bool get _notificationsEnabled =>
      _userMeta()['notifications_enabled'] as bool? ?? true;
  bool get _weeklySummaryEnabled =>
      _userMeta()['notify_weekly_summary'] as bool? ?? true;
  bool get _streakReminderEnabled =>
      _userMeta()['streak_reminder'] as bool? ?? true;
  bool get _goalRemindersEnabled =>
      _userMeta()['notify_goal_reminders'] as bool? ?? true;

  // ═══════════════════════════════════════════════════════
  //  SCHEDULED NOTIFICATIONS — call once on app open
  // ═══════════════════════════════════════════════════════

  /// Master method: schedule or cancel all repeating notifications.
  Future<void> syncScheduledNotifications() async {
    if (!_initialized) return;

    // ── Streak reminder: daily at 20:00 ──
    if (_notificationsEnabled && _streakReminderEnabled) {
      await _scheduleDaily(
        id: _kStreakReminderId,
        hour: 20,
        minute: 0,
        title: 'Keep your streak alive!',
        body: "You haven't logged a session today. A quick set keeps the momentum going.",
      );
    } else {
      await _plugin.cancel(id: _kStreakReminderId);
    }

    // ── Goal progress: Sunday at 18:00 ──
    if (_notificationsEnabled && _goalRemindersEnabled) {
      final goal = _userMeta()['weekly_makes_goal'] as int? ?? 200;
      await _scheduleWeekly(
        id: _kGoalProgressId,
        weekday: DateTime.sunday,
        hour: 18,
        minute: 0,
        title: 'Weekly goal check-in',
        body: 'How are you tracking against your $goal makes goal? Open Hooplytics to check.',
      );
    } else {
      await _plugin.cancel(id: _kGoalProgressId);
    }
  }

  // ═══════════════════════════════════════════════════════
  //  WEEKLY SUMMARY — on app open, once per week
  // ═══════════════════════════════════════════════════════

  Future<void> checkWeeklySummary() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    if (!_notificationsEnabled || !_weeklySummaryEnabled) return;

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final mondayMidnight =
        DateTime(weekStart.year, weekStart.month, weekStart.day);

    // Already sent this week?
    final existing = await client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('type', 'weekly_summary')
        .gte('created_at', mondayMidnight.toIso8601String())
        .limit(1);
    if ((existing as List).isNotEmpty) return;

    // Wait until Tuesday so Mon data exists
    if (now.weekday < 2) return;

    // Last week's sessions
    final lastWeekStart = mondayMidnight.subtract(const Duration(days: 7));
    final lwResp = await client
        .from('sessions')
        .select('made, attempts, best_streak')
        .eq('user_id', userId)
        .gte('created_at', lastWeekStart.toIso8601String())
        .lt('created_at', mondayMidnight.toIso8601String());

    // This week so far
    final twResp = await client
        .from('sessions')
        .select('made, attempts, best_streak')
        .eq('user_id', userId)
        .gte('created_at', mondayMidnight.toIso8601String());

    final lw = lwResp as List;
    final tw = twResp as List;

    const title = 'Weekly Summary';
    final body = _buildSummaryBody(lw, tw);
    final data = _buildSummaryData(lw, tw);

    await client.from('notifications').insert({
      'user_id': userId,
      'type': 'weekly_summary',
      'title': title,
      'body': body,
      'data': data,
    });

    await _show(title, body);
  }

  Map<String, dynamic> _buildSummaryData(List<dynamic> lw, List<dynamic> tw) {
    int lwMade = 0, lwAttempts = 0, lwBest = 0;
    for (final s in lw) {
      lwMade += (s['made'] as int?) ?? 0;
      lwAttempts += (s['attempts'] as int?) ?? 0;
      final bs = (s['best_streak'] as int?) ?? 0;
      if (bs > lwBest) lwBest = bs;
    }
    int twMade = 0, twAttempts = 0, twBest = 0;
    for (final s in tw) {
      twMade += (s['made'] as int?) ?? 0;
      twAttempts += (s['attempts'] as int?) ?? 0;
      final bs = (s['best_streak'] as int?) ?? 0;
      if (bs > twBest) twBest = bs;
    }
    return {
      'lw_sessions': lw.length,
      'lw_made': lwMade,
      'lw_attempts': lwAttempts,
      'lw_pct': lwAttempts > 0 ? (lwMade / lwAttempts * 100).round() : 0,
      'lw_best_streak': lwBest,
      'tw_sessions': tw.length,
      'tw_made': twMade,
      'tw_attempts': twAttempts,
      'tw_pct': twAttempts > 0 ? (twMade / twAttempts * 100).round() : 0,
      'tw_best_streak': twBest,
    };
  }

  String _buildSummaryBody(List<dynamic> lw, List<dynamic> tw) {
    if (lw.isEmpty && tw.isEmpty) {
      return 'No sessions recorded recently. Hit the court and start tracking!';
    }

    int lwMade = 0, lwAttempts = 0;
    for (final s in lw) {
      lwMade += (s['made'] as int?) ?? 0;
      lwAttempts += (s['attempts'] as int?) ?? 0;
    }
    int twMade = 0, twAttempts = 0;
    for (final s in tw) {
      twMade += (s['made'] as int?) ?? 0;
      twAttempts += (s['attempts'] as int?) ?? 0;
    }

    final parts = <String>[];
    if (lw.isNotEmpty) {
      final pct = lwAttempts > 0 ? (lwMade / lwAttempts * 100).round() : 0;
      parts.add(
          '${lw.length} ${lw.length == 1 ? "session" : "sessions"} last week — $lwMade/$lwAttempts ($pct%)');
    } else {
      parts.add('No sessions last week.');
    }

    if (tw.isNotEmpty && lw.isNotEmpty && lwAttempts > 0 && twAttempts > 0) {
      final diff = (twMade / twAttempts - lwMade / lwAttempts) * 100;
      if (diff > 0) {
        parts.add('Accuracy up ${diff.round()}% this week!');
      } else if (diff < -3) {
        parts.add('Accuracy dipped — time to lock in.');
      }
    }

    return parts.join(' ');
  }

  // ═══════════════════════════════════════════════════════
  //  STREAK CHECK — call on app open, saves to DB if needed
  // ═══════════════════════════════════════════════════════

  Future<void> checkStreakReminder() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    if (!_notificationsEnabled || !_streakReminderEnabled) return;

    // Already sent a streak reminder today?
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final existing = await client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('type', 'streak_reminder')
        .gte('created_at', todayStart.toIso8601String())
        .limit(1);
    if ((existing as List).isNotEmpty) return;

    // Check if user had a session today
    final todaySessions = await client
        .from('sessions')
        .select('id')
        .eq('user_id', userId)
        .gte('created_at', todayStart.toIso8601String())
        .limit(1);
    if ((todaySessions as List).isNotEmpty) return;

    // Check if user had sessions in the last 2 days (streak exists)
    final twoDaysAgo = todayStart.subtract(const Duration(days: 2));
    final recentSessions = await client
        .from('sessions')
        .select('id')
        .eq('user_id', userId)
        .gte('created_at', twoDaysAgo.toIso8601String())
        .lt('created_at', todayStart.toIso8601String())
        .limit(1);

    // Only warn if there's a streak to lose
    if ((recentSessions as List).isEmpty) return;

    // Only remind after 18:00
    if (today.hour < 18) return;

    await client.from('notifications').insert({
      'user_id': userId,
      'type': 'streak_reminder',
      'title': 'Streak at risk!',
      'body':
          "You haven't logged a session today. A quick set keeps your streak alive!",
    });
  }

  // ═══════════════════════════════════════════════════════
  //  GOAL PROGRESS — call on app open, Sunday+
  // ═══════════════════════════════════════════════════════

  Future<void> checkGoalProgress() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    if (!_notificationsEnabled || !_goalRemindersEnabled) return;

    final now = DateTime.now();
    // Only on Sunday+
    if (now.weekday < DateTime.sunday) return;

    final todayStart = DateTime(now.year, now.month, now.day);
    final existing = await client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('type', 'goal_progress')
        .gte('created_at', todayStart.toIso8601String())
        .limit(1);
    if ((existing as List).isNotEmpty) return;

    // This week's data
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final mondayMidnight =
        DateTime(weekStart.year, weekStart.month, weekStart.day);

    final resp = await client
        .from('sessions')
        .select('made')
        .eq('user_id', userId)
        .gte('created_at', mondayMidnight.toIso8601String());

    final sessions = resp as List;
    int totalMade = 0;
    for (final s in sessions) {
      totalMade += (s['made'] as int?) ?? 0;
    }

    final goal = _userMeta()['weekly_makes_goal'] as int? ?? 200;
    final pct = goal > 0 ? (totalMade / goal * 100).round() : 0;

    String title, body;
    if (pct >= 100) {
      title = 'Goal crushed!';
      body = 'You hit $totalMade makes this week — $pct% of your $goal goal. Keep dominating!';
    } else if (pct >= 70) {
      title = 'Almost there!';
      body = '$totalMade/$goal makes ($pct%). One more session could seal it!';
    } else {
      title = 'Weekly goal update';
      body = '$totalMade/$goal makes ($pct%). Still time to grind — you got this.';
    }

    await client.from('notifications').insert({
      'user_id': userId,
      'type': 'goal_progress',
      'title': title,
      'body': body,
      'data': {'made': totalMade, 'goal': goal, 'pct': pct},
    });

    await _show(title, body);
  }

  // ═══════════════════════════════════════════════════════
  //  GENERIC + CRUD
  // ═══════════════════════════════════════════════════════

  Future<void> sendNotification({
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    bool showPush = true,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    if (!_notificationsEnabled) return;

    await client.from('notifications').insert({
      'user_id': userId,
      'type': type,
      'title': title,
      'body': body,
      if (data != null) 'data': data,
    });

    if (showPush) await _show(title, body);
  }

  Future<List<Map<String, dynamic>>> getNotifications({int limit = 50}) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    final resp = await client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(resp as List);
  }

  Future<int> unreadCount() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return 0;

    final resp = await client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);

    return (resp as List).length;
  }

  Future<void> markAsRead(String id) async {
    await client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllAsRead() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  Future<void> deleteNotification(String id) async {
    await client.from('notifications').delete().eq('id', id);
  }

  Future<void> clearAll() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    await client.from('notifications').delete().eq('user_id', userId);
  }
}
