import '../models/session.dart';
import '../models/shot.dart';
import 'base_service.dart';

class SessionService extends BaseService {
  /// Saves a complete session including all shots.
  /// Uses an RPC if available, or sequential inserts.
  /// Since we don't have a specific RPC defined, we'll insert Session,
  /// get the generated UUID, and insert shots.
  Future<void> saveSessionData(Session session, List<Shot> shots) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No logged-in user to save session for.');
      }

      // 1. Build session JSON and always override user_id from auth
      final sessionJson = session.toJson();
      sessionJson['user_id'] = userId;

      // 2. Insert session and get the inserted record (which contains the ID)
      final sessionData =
          await client.from('sessions').insert(sessionJson).select().single();

      final sessionId = sessionData['id'] as String;

      // 3. Prepare shots with the correct session_id and user_id
      if (shots.isNotEmpty) {
        final shotsJson = shots.map((shot) {
          final j = shot.toJson();
          j['session_id'] = sessionId;
          j['user_id'] = userId;
          return j;
        }).toList();

        // 4. Insert shots in a single batch
        await client.from('shots').insert(shotsJson);
      }
    } catch (e) {
      throw Exception('Failed to save session: $e');
    }
  }

  Future<List<Session>> getHistory() async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No logged-in user to fetch history for.');
      }

      final response = await client
          .from('sessions')
          .select('*, shots(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => Session.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch history: $e');
    }
  }

  Future<Session> getSession(String sessionId) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not logged in');

      final response = await client
          .from('sessions')
          .select('*, shots(*)')
          .eq('id', sessionId)
          .eq('user_id', userId)
          .single();

      return Session.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch session: $e');
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not logged in');

      // Deleting the session will cascade delete shots if the DB is set up that way,
      // but just in case, we'll do it manually if needed or rely on the query.
      await client
          .from('sessions')
          .delete()
          .eq('id', sessionId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete session: $e');
    }
  }

  /// Updates an existing manual session and replaces its shots.
  Future<void> updateManualSession(Session session, List<Shot> shots) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not logged in');
      final sessionId = session.id;
      if (sessionId == null) throw Exception('Session ID required for update');

      // 1. Update session record
      await client
          .from('sessions')
          .update(session.toJson())
          .eq('id', sessionId)
          .eq('user_id', userId);

      // 2. Delete existing shots for this session
      await client
          .from('shots')
          .delete()
          .eq('session_id', sessionId)
          .eq('user_id', userId);

      // 3. Insert new shots
      if (shots.isNotEmpty) {
        final shotsJson = shots.map((shot) {
          final j = shot.toJson();
          j['session_id'] = sessionId;
          j['user_id'] = userId;
          return j;
        }).toList();

        await client.from('shots').insert(shotsJson);
      }
    } catch (e) {
      throw Exception('Failed to update session: $e');
    }
  }

  /// Computes all stats used by StatsScreen from real DB data.
  Future<Map<String, dynamic>> getStatsData(
      {DateTime? startDate, DateTime? endDate}) async {
    final sessions = await getHistory();

    // ── Filter only shooting sessions (live + manual), exclude games ──
    var shootingSessions = sessions.where((s) => s.type != 'game').toList();

    // ── Apply date filtering if provided ──
    if (startDate != null) {
      shootingSessions = shootingSessions.where((s) {
        final d = s.createdAt;
        if (d == null) return false;
        return d.isAfter(startDate) || d.isAtSameMomentAs(startDate);
      }).toList();
    }
    if (endDate != null) {
      shootingSessions = shootingSessions.where((s) {
        final d = s.createdAt;
        if (d == null) return false;
        return d.isBefore(endDate) || d.isAtSameMomentAs(endDate);
      }).toList();
    }

    // ── Lifetime totals ──
    int totalMade = 0, totalAttempts = 0;
    int bestStreakAll = 0, bestSessionPctInt = 0;
    int totalShotsAllSessions = 0;

    for (final s in shootingSessions) {
      totalMade += s.made;
      totalAttempts += s.attempts;
      if (s.bestStreak > bestStreakAll) bestStreakAll = s.bestStreak;
      if (s.attempts > 0) {
        final pInt = (s.made / s.attempts * 100).round();
        if (pInt > bestSessionPctInt) bestSessionPctInt = pInt;
      }
      totalShotsAllSessions += s.attempts;
    }

    final totalSessions = shootingSessions.length;
    final avgShotsPerSession =
        totalSessions > 0 ? totalShotsAllSessions ~/ totalSessions : 0;
    final overallPct = totalAttempts > 0 ? totalMade / totalAttempts : 0.0;

    // ── Zone stats (by mode == 'range') ──
    final zoneMap = <String, Map<String, int>>{};
    for (final s in shootingSessions.where((s) => s.mode == 'range')) {
      final id = s.selectionId;
      zoneMap.putIfAbsent(id, () => {'made': 0, 'attempts': 0});
      zoneMap[id]!['made'] = zoneMap[id]!['made']! + s.made;
      zoneMap[id]!['attempts'] = zoneMap[id]!['attempts']! + s.attempts;
    }

    final zoneTierMap = {'layup': 0, 'close': 1, 'mid': 2, 'three': 3};
    final zoneLabelMap = {
      'layup': 'Layup',
      'close': 'Close Shot',
      'mid': 'Mid Range',
      'three': 'Three Point'
    };
    final zones = <Map<String, dynamic>>[];
    for (final id in ['layup', 'close', 'mid', 'three']) {
      final data = zoneMap[id] ?? {'made': 0, 'attempts': 0};
      final att = data['attempts']!;
      zones.add({
        'label': zoneLabelMap[id] ?? id,
        'pct': att > 0 ? data['made']! / att : 0.0,
        'made': data['made']!,
        'attempts': att,
        'tier': zoneTierMap[id] ?? 3,
      });
    }

    // ── Position stats (by mode == 'position') ──
    final posMap = <String, Map<String, int>>{};
    for (final s in shootingSessions.where((s) => s.mode == 'position')) {
      final label = s.selectionLabel;
      posMap.putIfAbsent(label, () => {'made': 0, 'attempts': 0});
      posMap[label]!['made'] = posMap[label]!['made']! + s.made;
      posMap[label]!['attempts'] = posMap[label]!['attempts']! + s.attempts;
    }

    final positions = <Map<String, dynamic>>[];
    for (final entry in posMap.entries) {
      if (entry.value['attempts']! > 0) {
        positions.add({
          'label': entry.key,
          'pct': entry.value['made']! / entry.value['attempts']!,
          'attempts': entry.value['attempts']!,
        });
      }
    }

    // ── Trend: last 7 days daily % ──
    final now = DateTime.now();
    final weekPct = <double>[];
    final weekLabels = <String>[];
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final daySessions = shootingSessions.where((s) {
        final d = s.createdAt;
        return d != null &&
            d.year == day.year &&
            d.month == day.month &&
            d.day == day.day;
      });
      int dMade = 0, dAtt = 0;
      for (final s in daySessions) {
        dMade += s.made;
        dAtt += s.attempts;
      }
      weekPct.add(dAtt > 0 ? dMade / dAtt : 0.0);
      weekLabels.add(dayNames[day.weekday - 1]);
    }

    // ── Trend: last 6 months monthly % ──
    final monthPct = <double>[];
    final monthLabels = <String>[];
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final mSessions = shootingSessions.where((s) {
        final d = s.createdAt;
        return d != null && d.year == month.year && d.month == month.month;
      });
      int mMade = 0, mAtt = 0;
      for (final s in mSessions) {
        mMade += s.made;
        mAtt += s.attempts;
      }
      monthPct.add(mAtt > 0 ? mMade / mAtt : 0.0);
      monthLabels.add(monthNames[month.month - 1]);
    }

    // ── Calendar heatmap: last 5 weeks × 7 days ──
    final calendarData = <List<double>>[];
    final startOfWeek =
        now.subtract(Duration(days: now.weekday - 1)); // Monday of this week
    for (int w = 4; w >= 0; w--) {
      final weekStart = startOfWeek.subtract(Duration(days: w * 7));
      final row = <double>[];
      for (int d = 0; d < 7; d++) {
        final day = weekStart.add(Duration(days: d));
        final daySessions = shootingSessions.where((s) {
          final dt = s.createdAt;
          return dt != null &&
              dt.year == day.year &&
              dt.month == day.month &&
              dt.day == day.day;
        });
        int dMade = 0, dAtt = 0;
        for (final s in daySessions) {
          dMade += s.made;
          dAtt += s.attempts;
        }
        row.add(dAtt > 0 ? dMade / dAtt : 0.0);
      }
      calendarData.add(row);
    }

    // ── Current streak (consecutive days with sessions) ──
    int currentStreak = 0;
    for (int i = 0; i <= 365; i++) {
      final day = now.subtract(Duration(days: i));
      final hasSessions = shootingSessions.any((s) {
        final d = s.createdAt;
        return d != null &&
            d.year == day.year &&
            d.month == day.month &&
            d.day == day.day;
      });
      if (hasSessions) {
        currentStreak++;
      } else if (i > 0) {
        break;
      }
    }

    // ── Consistency score (% of last 14 days with sessions) ──
    int activeDays = 0;
    for (int i = 0; i < 14; i++) {
      final day = now.subtract(Duration(days: i));
      final hasSessions = shootingSessions.any((s) {
        final d = s.createdAt;
        return d != null &&
            d.year == day.year &&
            d.month == day.month &&
            d.day == day.day;
      });
      if (hasSessions) activeDays++;
    }
    final consistencyScore = activeDays / 14.0;

    // ── Week-over-week change ──
    final thisWeekSessions = shootingSessions.where((s) {
      final d = s.createdAt;
      return d != null && now.difference(d).inDays < 7;
    });
    final lastWeekSessions = shootingSessions.where((s) {
      final d = s.createdAt;
      return d != null &&
          now.difference(d).inDays >= 7 &&
          now.difference(d).inDays < 14;
    });
    int twMade = 0, twAtt = 0, lwMade = 0, lwAtt = 0;
    for (final s in thisWeekSessions) {
      twMade += s.made;
      twAtt += s.attempts;
    }
    for (final s in lastWeekSessions) {
      lwMade += s.made;
      lwAtt += s.attempts;
    }
    final twPct = twAtt > 0 ? twMade / twAtt : 0.0;
    final lwPct = lwAtt > 0 ? lwMade / lwAtt : 0.0;
    final weekChange = (twPct - lwPct) * 100;

    // ── Recent sessions (last 5 shooting sessions) ──
    final recentSessions = shootingSessions.take(5).map((s) {
      return {
        'session': s.toJson(),
        'timeAgo': _timeAgo(s.createdAt),
      };
    }).toList();

    return {
      'totalMade': totalMade,
      'totalAttempts': totalAttempts,
      'overallPct': overallPct,
      'totalSessions': totalSessions,
      'avgShotsPerSession': avgShotsPerSession,
      'bestStreak': bestStreakAll,
      'currentStreak': currentStreak,
      'bestSessionPct': bestSessionPctInt,
      'consistencyScore': consistencyScore,
      'weekChange': weekChange,
      'weekPct': weekPct,
      'weekLabels': weekLabels,
      'monthPct': monthPct,
      'monthLabels': monthLabels,
      'zones': zones,
      'positions': positions,
      'calendarData': calendarData,
      'recentSessions': recentSessions,
    };
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}.${date.month}.${date.year}';
  }

  /// Fetches aggregate stats for a specific selection ID (zone or position).
  Future<Map<String, dynamic>> getSelectionStats(
      String selectionId, String mode) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('No user');

    final response = await client
        .from('sessions')
        .select('made, attempts')
        .eq('user_id', userId)
        .eq('selection_id', selectionId)
        .eq('mode', mode)
        .neq('type', 'game');

    final list = response as List;
    int totalMade = 0;
    int totalAttempts = 0;

    for (final row in list) {
      totalMade += (row['made'] as num).toInt();
      totalAttempts += (row['attempts'] as num).toInt();
    }

    return {
      'made': totalMade,
      'attempts': totalAttempts,
    };
  }
}
