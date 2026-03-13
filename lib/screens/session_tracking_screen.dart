// lib/screens/session_tracking_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../main.dart';
import '../models/shot.dart';
import '../models/session.dart';
import '../services/session_service.dart';
import '../utils/performance.dart';
import '../widgets/tracking_body.dart';
import 'session_setup_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  SESSION TRACKING SCREEN
//  Thin wrapper that provides session context to TrackingBody.
//  Shows _SummarySheet when tracking completes.
// ═══════════════════════════════════════════════════════════════════════════

class SessionTrackingScreen extends StatelessWidget {
  final SessionMode mode;
  final String selectionId;
  final String selectionLabel;
  final int targetShots;

  const SessionTrackingScreen({
    super.key,
    required this.mode,
    required this.selectionId,
    required this.selectionLabel,
    this.targetShots = 25,
  });

  void _showSummary(BuildContext context, TrackingResult result) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (_) => _SummarySheet(
        label: selectionLabel,
        mode: mode,
        selectionId: selectionId,
        targetShots: targetShots,
        made: result.made,
        swishes: result.swishes,
        attempts: result.attempts,
        bestStreak: result.bestStreak,
        elapsed: result.elapsed,
        log: result.log,
        onSave: () => Navigator.of(context).popUntil((r) => r.isFirst),
        onDiscard: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: TrackingBody(
          title: selectionLabel,
          subtitle: mode == SessionMode.position ? 'POSITION' : 'RANGE',
          voiceEnabled: true,
          swishEnabled: true,
          onBack: () => Navigator.of(context).pop(),
          onFinished: (result) => _showSummary(context, result),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SUMMARY SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _SummarySheet extends StatefulWidget {
  final String label;
  final SessionMode mode;
  final String selectionId;
  final int targetShots, made, swishes, attempts, bestStreak;
  final Duration elapsed;
  final List<ShotResult> log;
  final VoidCallback onSave, onDiscard;

  const _SummarySheet({
    required this.label,
    required this.mode,
    required this.selectionId,
    required this.targetShots,
    required this.made,
    required this.swishes,
    required this.attempts,
    required this.bestStreak,
    required this.elapsed,
    required this.log,
    required this.onSave,
    required this.onDiscard,
  });

  @override
  State<_SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends State<_SummarySheet> {
  bool _saving = false;

  String get _pct => widget.attempts == 0
      ? '0%'
      : '${(widget.made / widget.attempts * 100).round()}%';

  String get _time {
    final m =
        widget.elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s =
        widget.elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _grade {
    if (widget.attempts == 0) return '—';
    return PerformanceGuide.gradeFor(widget.made / widget.attempts);
  }

  Color get _gc {
    if (widget.attempts == 0) return AppColors.text3;
    return PerformanceGuide.colorFor(widget.made / widget.attempts);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      final session = Session(
        userId: user.id,
        type: 'live',
        mode: widget.mode == SessionMode.position ? 'position' : 'range',
        selectionId: widget.selectionId,
        selectionLabel: widget.label,
        targetShots: widget.targetShots,
        made: widget.made,
        swishes: widget.swishes,
        attempts: widget.attempts,
        bestStreak: widget.bestStreak,
        elapsedSeconds: widget.elapsed.inSeconds,
      );
      final shots = widget.log
          .asMap()
          .entries
          .map((e) => Shot(
                sessionId: '',
                userId: user.id,
                orderIdx: e.key,
                isMake: e.value != ShotResult.miss,
                isSwish: e.value == ShotResult.swish,
              ))
          .toList();
      await SessionService().saveSessionData(session, shots);
      widget.onSave();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 36,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)))),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SESSION COMPLETE',
                        style: AppText.ui(10,
                            color: AppColors.text3,
                            letterSpacing: 1.8,
                            weight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(widget.label,
                        style: AppText.ui(22, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.timer_outlined,
                          size: 13, color: AppColors.text3),
                      const SizedBox(width: 5),
                      Text(_time,
                          style: AppText.ui(12, color: AppColors.text3)),
                    ]),
                  ]),
            ),
            Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: _gc.withValues(alpha: 0.08),
                    border: Border.all(
                        color: _gc.withValues(alpha: 0.4), width: 1.5),
                    borderRadius: BorderRadius.circular(16)),
                child: Center(
                    child: Text(_grade,
                        style: AppText.display(34, color: _gc)))),
          ]),
          const SizedBox(height: 20),
          Container(height: 1, color: AppColors.borderSub),
          const SizedBox(height: 18),
          Row(children: [
            _SumTile('MADE', '${widget.made}', AppColors.gold),
            _SumTile('SWISHES', '${widget.swishes}', AppColors.green),
            _SumTile('ACCURACY', _pct, _gc),
            _SumTile('STREAK', '${widget.bestStreak}', AppColors.gold),
          ]),
          if (widget.log.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('SHOT LOG',
                style: AppText.ui(10,
                    color: AppColors.text3,
                    letterSpacing: 1.8,
                    weight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: widget.log
                  .take(50)
                  .map((r) => Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: r == ShotResult.swish
                                ? AppColors.gold
                                : r == ShotResult.make
                                    ? AppColors.green
                                    : AppColors.red),
                      ))
                  .toList(),
            ),
            if (widget.log.length > 50) ...[
              const SizedBox(height: 6),
              Text('+ ${widget.log.length - 50} more',
                  style: AppText.ui(10, color: AppColors.text3)),
            ],
          ],
          const SizedBox(height: 28),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: widget.onDiscard,
                child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                        color: AppColors.surfaceHi,
                        borderRadius: BorderRadius.circular(14)),
                    child: Center(
                        child: Text('Discard',
                            style: AppText.ui(14,
                                weight: FontWeight.w700,
                                color: AppColors.text2)))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(14)),
                    child: Center(
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: AppColors.bg, strokeWidth: 2.5))
                            : Text('Save',
                                style: AppText.ui(14,
                                    weight: FontWeight.w700,
                                    color: AppColors.bg)))),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _SumTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SumTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: AppText.ui(19, weight: FontWeight.w700, color: color)),
          const SizedBox(height: 3),
          Text(label,
              style:
                  AppText.ui(9, color: AppColors.text3, letterSpacing: 0.8)),
        ]),
      );
}
