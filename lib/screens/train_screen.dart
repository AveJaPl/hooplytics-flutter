import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../main.dart';
import '../utils/haptics.dart';
import 'session_setup_screen.dart';
import 'three_point_contest_screen.dart';
import 'duel_screen.dart';
import 'horse_screen.dart';
import 'solo_challenge_screen.dart';
import 'game_setup_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  DATA  –  Game mode definitions
// ═════════════════════════════════════════════════════════════════════════════

enum ModeCategory { featured, social, challenge, classic }

class GameMode {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String details; // e.g. "25 shots · 5 racks"
  final IconData icon;
  final Color color;
  final ModeCategory category;
  final int players; // 1 = solo, 2 = duel
  final String difficulty; // 'Easy' 'Medium' 'Hard' 'Pro'
  final bool isNew;
  final bool isLocked;

  const GameMode({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.details,
    required this.icon,
    required this.color,
    required this.category,
    this.players = 1,
    required this.difficulty,
    this.isNew = false,
    this.isLocked = false,
  });
}

const _allModes = [
  // ── FEATURED ──────────────────────────────────────────────────────────────
  GameMode(
    id: 'three_point_contest',
    title: '3-Point Contest',
    subtitle: 'NBA All-Star style',
    description:
        'Hit as many threes as possible from 5 corner racks. Each rack has 5 balls — the last one is a money ball worth 2 points.',
    details: '25 shots · 5 racks · Timer optional',
    icon: Icons.sports_basketball_rounded,
    color: Color(0xFFD4A843),
    category: ModeCategory.featured,
    difficulty: 'Hard',
    isNew: false,
  ),

  // ── SOCIAL ────────────────────────────────────────────────────────────────
  GameMode(
    id: 'duel',
    title: 'Duel',
    subtitle: 'Challenge a friend',
    description:
        'Take turns shooting from the same spot. 10 shots each — the higher percentage wins. Trash talk included.',
    details: '2 players · 10 shots each',
    icon: Icons.people_rounded,
    color: Color(0xFF5E8FEF),
    category: ModeCategory.social,
    players: 2,
    difficulty: 'Medium',
  ),
  GameMode(
    id: 'horse',
    title: 'H-O-R-S-E',
    subtitle: 'Classic yard game',
    description:
        'Call your shot and nail it. Miss and your opponent gets a letter. Spell HORSE and you lose.',
    details: '2 players · Unlimited shots',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFAA5EEF),
    category: ModeCategory.social,
    players: 2,
    difficulty: 'Medium',
  ),

  // ── CHALLENGE ─────────────────────────────────────────────────────────────
  GameMode(
    id: 'beat_the_clock',
    title: 'Beat the Clock',
    subtitle: 'Race against time',
    description:
        'Sink as many shots as you can in 60 seconds. Quick release, good form, no hesitation.',
    details: '60 seconds · Any zone',
    icon: Icons.timer_rounded,
    color: Color(0xFFFF7A5C),
    category: ModeCategory.challenge,
    difficulty: 'Hard',
  ),
  GameMode(
    id: 'streak_mode',
    title: 'Streak Mode',
    subtitle: 'Don\'t break the chain',
    description:
        'Build the longest consecutive make streak you can. One miss ends the run. How far can you go?',
    details: 'Unlimited · Any zone',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFFF5252),
    category: ModeCategory.challenge,
    difficulty: 'Easy',
  ),
  GameMode(
    id: 'hot_spot',
    title: 'Hot Spot',
    subtitle: 'Find your zone',
    description:
        '10 shots from each of 5 positions. Your score is the total makes. Find out where you\'re deadliest.',
    details: '50 shots · 5 positions',
    icon: Icons.location_on_rounded,
    color: Color(0xFF3DD68C),
    category: ModeCategory.challenge,
    difficulty: 'Medium',
  ),
  GameMode(
    id: 'pressure_fts',
    title: 'Pressure FTs',
    subtitle: 'Clutch free throws',
    description:
        'Make 10 free throws in a row to pass each level. Miss and restart the level. Every make counts.',
    details: '10 consecutive · Free throw',
    icon: Icons.lens_rounded,
    color: Color(0xFF5E8FEF),
    category: ModeCategory.challenge,
    difficulty: 'Medium',
  ),

  // ── CLASSIC ──────────────────────────────────────────────────────────────
  GameMode(
    id: 'around_the_world',
    title: 'Around the World',
    subtitle: 'The classic game',
    description:
        'Hit shots from 7 spots in sequence around the arc. Miss twice in a row and you\'re stuck. Make it back faster each time.',
    details: '7 spots · Sequential',
    icon: Icons.public_rounded,
    color: Color(0xFF3DD68C),
    category: ModeCategory.classic,
    difficulty: 'Easy',
  ),
  GameMode(
    id: 'mikan_drill',
    title: 'Mikan Drill',
    subtitle: 'Big-man finisher',
    description:
        'Alternate layups from each side of the basket, 20 reps total. The most fundamental finishing drill in basketball.',
    details: '20 layups · Alternating',
    icon: Icons.swap_horiz_rounded,
    color: Color(0xFFD4A843),
    category: ModeCategory.classic,
    difficulty: 'Easy',
  ),
];

// ═════════════════════════════════════════════════════════════════════════════
//  TRAIN SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class TrainScreen extends StatefulWidget {
  const TrainScreen({super.key});
  @override
  State<TrainScreen> createState() => _TrainScreenState();
}

class _TrainScreenState extends State<TrainScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500))
    ..forward();

  int _filterIndex = 0; // 0=All 1=Solo 2=Multiplayer 3=Challenges

  static const _filters = ['All', 'Solo', 'Multiplayer', 'Challenges'];

  List<GameMode> get _filtered {
    switch (_filterIndex) {
      case 1:
        return _allModes.where((m) => m.players == 1).toList();
      case 2:
        return _allModes.where((m) => m.players == 2).toList();
      case 3:
        return _allModes
            .where((m) => m.category == ModeCategory.challenge)
            .toList();
      default:
        return _allModes;
    }
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _entry, curve: Curves.easeOut),
        child: SafeArea(
          child: Column(children: [
            _header(),
            _filterRow(),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                children: _buildContent(),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── header ────────────────────────────────────────────────────────────────

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TRAIN',
                style: AppText.ui(11,
                    color: AppColors.text2,
                    letterSpacing: 1.4,
                    weight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('Game Modes', style: AppText.ui(24, weight: FontWeight.w800)),
          ]),
        ]),
      );

  // ── filter row ────────────────────────────────────────────────────────────

  Widget _filterRow() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Row(
          children: List.generate(_filters.length, (i) {
            final on = _filterIndex == i;
            final isLast = i == _filters.length - 1;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  Haptics.selectionClick();
                  setState(() => _filterIndex = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 170),
                  margin: EdgeInsets.only(right: isLast ? 0 : 8),
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? AppColors.gold : AppColors.surface,
                    border: Border.all(
                      color: on ? AppColors.gold : AppColors.border,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _filters[i],
                    style: AppText.ui(
                      11,
                      weight: FontWeight.w600,
                      color: on ? AppColors.bg : AppColors.text2,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      );

  // ── content list builder ──────────────────────────────────────────────────

  List<Widget> _buildContent() {
    final modes = _filtered;
    if (modes.isEmpty) {
      return [
        const SizedBox(
            height: 80,
            child: Center(
                child: Text('No modes found',
                    style: TextStyle(color: AppColors.text3))))
      ];
    }

    final widgets = <Widget>[];

    // If showing All — group by featured/social/challenge/classic
    if (_filterIndex == 0) {
      // Featured — big horizontal card
      final featured =
          modes.where((m) => m.category == ModeCategory.featured).toList();
      if (featured.isNotEmpty) {
        widgets.add(_sectionLabel('FEATURED'));
        widgets.add(_FeaturedCard(
            mode: featured.first, onTap: () => _launch(featured.first)));
        widgets.add(const SizedBox(height: 28));
      }

      // Social — side by side 2-col
      final social =
          modes.where((m) => m.category == ModeCategory.social).toList();
      if (social.isNotEmpty) {
        widgets.add(_sectionLabel('MULTIPLAYER'));
        widgets.add(_TwoColGrid(modes: social, onTap: _launch));
        widgets.add(const SizedBox(height: 28));
      }

      // Challenges — vertical list
      final challenges =
          modes.where((m) => m.category == ModeCategory.challenge).toList();
      if (challenges.isNotEmpty) {
        widgets.add(_sectionLabel('CHALLENGES'));
        for (final m in challenges) {
          widgets.add(_ListCard(mode: m, onTap: () => _launch(m)));
          widgets.add(const SizedBox(height: 10));
        }
        widgets.add(const SizedBox(height: 18));
      }

      // Classic — vertical list
      final classic =
          modes.where((m) => m.category == ModeCategory.classic).toList();
      if (classic.isNotEmpty) {
        widgets.add(_sectionLabel('CLASSIC DRILLS'));
        for (final m in classic) {
          widgets.add(_ListCard(mode: m, onTap: () => _launch(m)));
          widgets.add(const SizedBox(height: 10));
        }
      }
    } else {
      // Filtered view — all as list cards
      for (final m in modes) {
        widgets.add(_ListCard(mode: m, onTap: () => _launch(m)));
        widgets.add(const SizedBox(height: 10));
      }
    }

    return widgets;
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Text(text,
              style: AppText.ui(11,
                  color: AppColors.text2,
                  letterSpacing: 1.4,
                  weight: FontWeight.w800)),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: AppColors.borderSub)),
        ]),
      );

  void _launch(GameMode mode) {
    Haptics.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ModeDetailSheet(
          mode: mode,
          onStart: () {
            Navigator.pop(context);
            _navigateToMode(mode);
          }),
    );
  }

  void _navigateToMode(GameMode mode) {
    Widget screen;
    switch (mode.id) {
      case 'three_point_contest':
        screen = const ThreePointContestScreen();
      case 'duel':
        screen = const DuelScreen();
      case 'horse':
        screen = const HorseScreen();
      case 'beat_the_clock':
      case 'streak_mode':
        screen = GameSetupScreen(
            modeId: mode.id,
            title: mode.title,
            color: mode.color,
            requiredPositions: 1);
      case 'hot_spot':
        screen = GameSetupScreen(
            modeId: mode.id,
            title: mode.title,
            color: mode.color,
            requiredPositions: 5);
      case 'pressure_fts':
        _showFtDifficultyPicker(mode);
        return;
      case 'around_the_world':
      case 'mikan_drill':
        screen = SoloChallengeScreen(
            modeId: mode.id, title: mode.title, color: mode.color);
      default:
        screen = const SessionSetupScreen();
    }
    Navigator.push(context, _fade(screen));
  }

  void _showFtDifficultyPicker(GameMode mode) {
    Haptics.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FtDifficultySheet(
        color: mode.color,
        onSelect: (target) {
          Navigator.pop(context);
          Navigator.push(
              context,
              _fade(SoloChallengeScreen(
                  modeId: mode.id,
                  title: mode.title,
                  color: mode.color,
                  ftTargetOverride: target)));
        },
      ),
    );
  }

  PageRoute _fade(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 320),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
            child: child),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
//  CARD WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

// ── Featured card (tall, full-width, gradient) ────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  final GameMode mode;
  final VoidCallback onTap;
  const _FeaturedCard({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 192,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              mode.color.withValues(alpha: 0.85),
              mode.color.withValues(alpha: 0.40)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
                color: mode.color.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 6))
          ],
        ),
        child: Stack(children: [
          // Background icon watermark
          Positioned(
              right: -16,
              bottom: -16,
              child: Icon(mode.icon,
                  size: 150, color: Colors.white.withValues(alpha: 0.12))),
          // Difficulty pill top-right
          Positioned(top: 16, right: 16, child: _DiffPill(mode.difficulty)),
          // Content
          Padding(
            padding: const EdgeInsets.all(22),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Category label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(6)),
                child: Text('FEATURED',
                    style: AppText.ui(9,
                        weight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.3)),
              ),
              const Spacer(),
              Text(mode.title,
                  style: AppText.ui(24,
                      weight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 5),
              Text(mode.details,
                  style: AppText.ui(13,
                      color: Colors.white.withValues(alpha: 0.75))),
              const SizedBox(height: 14),
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.play_arrow_rounded,
                        size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text('Start',
                        style: AppText.ui(14,
                            weight: FontWeight.w800, color: Colors.white)),
                  ]),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── 2-column grid (for social/duel modes) ────────────────────────────────────

class _TwoColGrid extends StatelessWidget {
  final List<GameMode> modes;
  final void Function(GameMode) onTap;
  const _TwoColGrid({required this.modes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(math.min(modes.length, 2), (i) {
          final m = modes[i];
          return Expanded(
              child: Padding(
            padding:
                EdgeInsets.only(right: i == 0 ? 8 : 0, left: i == 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => onTap(m),
              child: Container(
                height: 170,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: m.color.withValues(alpha: 0.12)),
                          child: Icon(m.icon, color: m.color, size: 20),
                        ),
                        const Spacer(),
                        if (m.isNew) _NewBadge(),
                      ]),
                      const Spacer(),
                      Text(m.title,
                          style: AppText.ui(15, weight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(m.subtitle,
                          style: AppText.ui(12, color: AppColors.text2)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Icon(Icons.people_outline_rounded,
                            size: 12, color: m.color),
                        const SizedBox(width: 5),
                        Text('${m.players}P',
                            style: AppText.ui(11,
                                weight: FontWeight.w600, color: m.color)),
                        const Spacer(),
                        _DiffPill(m.difficulty, small: true),
                      ]),
                    ]),
              ),
            ),
          ));
        }));
  }
}

// ── List card (horizontal) ────────────────────────────────────────────────────

class _ListCard extends StatelessWidget {
  final GameMode mode;
  final VoidCallback onTap;
  const _ListCard({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          // Color dot + icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: mode.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: mode.color.withValues(alpha: 0.22)),
            ),
            child: Icon(mode.icon, color: mode.color, size: 24),
          ),
          const SizedBox(width: 14),
          // Text
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Text(mode.title,
                      style: AppText.ui(15, weight: FontWeight.w700)),
                  if (mode.isNew) ...[const SizedBox(width: 7), _NewBadge()],
                ]),
                const SizedBox(height: 3),
                Text(mode.details,
                    style: AppText.ui(12, color: AppColors.text2)),
              ])),
          const SizedBox(width: 10),
          // Diff pill
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _DiffPill(mode.difficulty, small: true),
          ]),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  MODE DETAIL BOTTOM SHEET
// ═════════════════════════════════════════════════════════════════════════════

class _ModeDetailSheet extends StatelessWidget {
  final GameMode mode;
  final VoidCallback onStart;
  const _ModeDetailSheet({required this.mode, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 0),
          child: Center(
              child: Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)))),
        ),

        // Header band with gradient
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              mode.color.withValues(alpha: 0.25),
              mode.color.withValues(alpha: 0.06)
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: mode.color.withValues(alpha: 0.22)),
          ),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mode.color.withValues(alpha: 0.18)),
              child: Icon(mode.icon, color: mode.color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(mode.title,
                      style: AppText.ui(20, weight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(mode.subtitle,
                      style: AppText.ui(13, color: AppColors.text2)),
                ])),
            _DiffPill(mode.difficulty),
          ]),
        ),

        // Body
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Description
            Text(
              mode.description,
              style: AppText.ui(14, color: AppColors.text2),
            ),
            const SizedBox(height: 20),

            // Info chips row
            Row(children: [
              _InfoChip(Icons.sports_basketball_outlined,
                  mode.details.split('·')[0].trim()),
              const SizedBox(width: 8),
              if (mode.players > 1)
                _InfoChip(
                    Icons.people_outline_rounded, '${mode.players} players')
              else
                const _InfoChip(Icons.person_outline_rounded, 'Solo'),
              const SizedBox(width: 8),
              _InfoChip(Icons.bar_chart_rounded, mode.difficulty),
            ]),
            const SizedBox(height: 24),

            // Rules mini-list (hardcoded per mode)
            if (_rules(mode.id).isNotEmpty) ...[
              Text('HOW IT WORKS',
                  style: AppText.ui(9,
                      color: AppColors.text3,
                      letterSpacing: 1.6,
                      weight: FontWeight.w700)),
              const SizedBox(height: 12),
              ..._rules(mode.id).asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: mode.color.withValues(alpha: 0.14)),
                            child: Center(
                                child: Text('${e.key + 1}',
                                    style: AppText.ui(10,
                                        weight: FontWeight.w800,
                                        color: mode.color))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(e.value,
                                  style:
                                      AppText.ui(13, color: AppColors.text2))),
                        ]),
                  )),
              const SizedBox(height: 8),
            ],
          ]),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          child: GestureDetector(
            onTap: onStart,
            child: Container(
              height: 54, // Slightly taller for better ergonomics
              decoration: BoxDecoration(
                color: mode.color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: mode.color.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 5))
                ],
              ),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.play_arrow_rounded,
                    color: Colors.black, size: 24),
                const SizedBox(width: 8),
                Text('Start Game',
                    style: AppText.ui(16,
                        weight: FontWeight.w800, color: Colors.black)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  List<String> _rules(String id) {
    switch (id) {
      case 'three_point_contest':
        return [
          'Shoot from 5 positions along the 3-point arc.',
          'Each position has 5 balls. The last ball (money ball) counts as 2 points.',
          'Timer is optional — enable or disable in setup.',
          'Highest score wins. NBA record is 27/30.',
        ];
      case 'duel':
        return [
          'Both players select the same spot on the court.',
          'Player 1 takes 10 shots, Player 2 takes 10 shots.',
          'Highest shooting percentage wins the round.',
          'Play best of 3 rounds to crown the winner.',
        ];
      case 'horse':
        return [
          'Player 1 calls a shot and takes it. If made, Player 2 must match it.',
          'If Player 2 misses, they get the next letter (H-O-R-S-E).',
          'If Player 1 misses, no letter is given and Player 2 leads next.',
          'First player to spell HORSE loses.',
        ];
      case 'beat_the_clock':
        return [
          'Choose any zone before the game starts.',
          'Timer counts down from 60 seconds.',
          'Make as many shots as possible before time runs out.',
          'If you released your shot before the buzzer, you can still record it.',
        ];
      case 'streak_mode':
        return [
          'Shoot continuously from any spot.',
          'Your current streak counts every consecutive make.',
          'One miss ends the streak — count resets to 0.',
          'Goal: beat your personal best streak.',
        ];
      case 'hot_spot':
        return [
          '5 pre-selected positions are chosen for you.',
          'Take 10 shots from each position.',
          'Your total is scored out of 50.',
          'Your hottest and coldest zones are highlighted.',
        ];
      case 'pressure_fts':
        return [
          'Shoot free throws one at a time.',
          'You need 10 consecutive makes to clear a level.',
          'Miss at any point and the current level restarts.',
          'Complete 5 levels to finish the challenge.',
        ];
      case 'around_the_world':
        return [
          '7 shooting spots are marked around the arc.',
          'Make a shot from each spot to advance.',
          'Miss twice in a row from the same spot and you\'re stuck.',
          'Complete all 7 spots to finish.',
        ];
      case 'mikan_drill':
        return [
          'Start under the basket on the right side.',
          'Make a right-hand layup, grab the net, move to left side.',
          'Make a left-hand layup — that\'s 1 rep.',
          'Complete 20 reps. Focus on footwork and soft touch.',
        ];
      default:
        return [];
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  MICRO-COMPONENTS
// ═════════════════════════════════════════════════════════════════════════════

class _DiffPill extends StatelessWidget {
  final String label;
  final bool small;
  const _DiffPill(this.label, {this.small = false});

  Color get _color {
    switch (label) {
      case 'Easy':
        return const Color(0xFF3DD68C);
      case 'Medium':
        return const Color(0xFFD4A843);
      case 'Hard':
        return const Color(0xFFFF7A5C);
      case 'Pro':
        return const Color(0xFF5E8FEF);
      default:
        return AppColors.text3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 7 : 10, vertical: small ? 3 : 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.30)),
      ),
      child: Text(label,
          style: AppText.ui(small ? 11 : 12,
              weight: FontWeight.w700, color: _color)),
    );
  }
}

class _NewBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(5)),
        child: Text('NEW',
            style: AppText.ui(11,
                weight: FontWeight.w800,
                color: AppColors.gold,
                letterSpacing: 0.4)),
      );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: AppColors.bg,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: AppColors.text2),
          const SizedBox(width: 5),
          Text(label,
              style: AppText.ui(12,
                  color: AppColors.text2, weight: FontWeight.w500)),
        ]),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
//  PRESSURE FREE THROWS — DIFFICULTY PICKER
// ═════════════════════════════════════════════════════════════════════════════

class _FtDifficultySheet extends StatelessWidget {
  final Color color;
  final void Function(int target) onSelect;

  const _FtDifficultySheet({required this.color, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
          child: Container(
            width: 36,
            height: 3,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Text('SELECT DIFFICULTY',
            style: AppText.ui(11,
                color: color,
                letterSpacing: 1.6,
                weight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Pressure Free Throws',
            style: AppText.ui(20, weight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('How many consecutive makes per level?',
            style: AppText.ui(13, color: AppColors.text2)),
        const SizedBox(height: 24),
        _diffOption(context, 'Easy', '3 in a row', 3,
            const Color(0xFF3DD68C)),
        const SizedBox(height: 10),
        _diffOption(context, 'Medium', '5 in a row', 5,
            const Color(0xFFD4A843)),
        const SizedBox(height: 10),
        _diffOption(context, 'Hard', '10 in a row', 10,
            const Color(0xFFFF7A5C)),
      ]),
    );
  }

  Widget _diffOption(BuildContext context, String label, String sub,
      int target, Color diffColor) {
    return GestureDetector(
      onTap: () {
        Haptics.mediumImpact();
        onSelect(target);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: diffColor.withValues(alpha: 0.12),
              border: Border.all(color: diffColor.withValues(alpha: 0.30)),
            ),
            child: Center(
              child: Text('$target',
                  style: AppText.display(18, color: diffColor)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppText.ui(15, weight: FontWeight.w700)),
                Text(sub,
                    style: AppText.ui(12, color: AppColors.text2)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.text3, size: 22),
        ]),
      ),
    );
  }
}
