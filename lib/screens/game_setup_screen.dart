import 'package:flutter/material.dart';
import '../main.dart';
import '../utils/haptics.dart';
import '../widgets/basketball_court_map.dart';
import 'solo_challenge_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  GAME SETUP SCREEN
//  Position picker before launching a game mode.
//  - streak_mode & beat_the_clock: pick exactly 1 position
//  - hot_spot: pick exactly 5 positions
// ═════════════════════════════════════════════════════════════════════════════

class GameSetupScreen extends StatefulWidget {
  final String modeId;
  final String title;
  final Color color;
  final int requiredPositions; // 1 for streak/btc, 5 for hot_spot

  const GameSetupScreen({
    super.key,
    required this.modeId,
    required this.title,
    required this.color,
    this.requiredPositions = 1,
  });

  @override
  State<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420))
    ..forward();

  final Set<String> _selected = {};

  static const _spotLabels = {
    'left_corner': 'Left Corner',
    'right_corner': 'Right Corner',
    'left_wing': 'Left Wing',
    'right_wing': 'Right Wing',
    'top_arc': 'Top of Arc',
    'left_elbow': 'Left Elbow',
    'right_elbow': 'Right Elbow',
    'left_block': 'Left Block',
    'right_block': 'Right Block',
    'free_throw': 'Free Throw',
    'high_arc': 'High Arc',
    'left_mid': 'Left Mid',
    'right_mid': 'Right Mid',
  };

  bool get _isSingle => widget.requiredPositions == 1;
  bool get _canStart =>
      _isSingle
          ? _selected.length == 1
          : _selected.length == widget.requiredPositions;

  String get _subtitle {
    if (_isSingle) {
      return _selected.isEmpty
          ? 'Select a position'
          : _spotLabels[_selected.first] ?? '';
    }
    return '${_selected.length} / ${widget.requiredPositions} positions selected';
  }

  List<MapSpotData> get _spots {
    return _spotLabels.entries
        .map((e) => MapSpotData(
              id: e.key,
              label: e.value,
              isSelected: _selected.contains(e.key),
            ))
        .toList();
  }

  void _onSpotTap(String id) {
    Haptics.selectionClick();
    setState(() {
      if (_isSingle) {
        _selected.clear();
        _selected.add(id);
      } else {
        if (_selected.contains(id)) {
          _selected.remove(id);
        } else if (_selected.length < widget.requiredPositions) {
          _selected.add(id);
        }
      }
    });
  }

  void _start() {
    if (!_canStart) return;
    Haptics.mediumImpact();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => SoloChallengeScreen(
          modeId: widget.modeId,
          title: widget.title,
          color: widget.color,
          selectedPositions: _selected.toList(),
        ),
        transitionDuration: const Duration(milliseconds: 320),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
            child: child),
      ),
    );
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _entry, curve: Curves.easeOut),
        child: SafeArea(
          child: Column(children: [
            _topBar(),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(children: [
                  _court(),
                  if (!_isSingle) ...[
                    const SizedBox(height: 12),
                    _selectedChips(),
                  ],
                ]),
              ),
            ),
            _bottom(),
          ]),
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 15, color: AppColors.text2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title.toUpperCase(),
                      style: AppText.ui(11,
                          color: widget.color,
                          letterSpacing: 1.4,
                          weight: FontWeight.w800)),
                  const SizedBox(height: 1),
                  Text(_subtitle,
                      style: AppText.ui(16, weight: FontWeight.w700)),
                ]),
          ),
        ]),
      );

  Widget _selectedChips() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _selected.map((id) {
            final label = _spotLabels[id] ?? id;
            return GestureDetector(
              onTap: () {
                Haptics.selectionClick();
                setState(() => _selected.remove(id));
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: widget.color.withValues(alpha: 0.30)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(label,
                      style: AppText.ui(12,
                          weight: FontWeight.w600, color: widget.color)),
                  const SizedBox(width: 5),
                  Icon(Icons.close_rounded, size: 13, color: widget.color),
                ]),
              ),
            );
          }).toList(),
        ),
      );

  Widget _court() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: BasketballCourtMap(
          themeColor: widget.color,
          mode: CourtMapMode.setup,
          selectedId: _selected.isEmpty ? null : _selected.last,
          onSpotTap: _onSpotTap,
          spots: _spots,
        ),
      );

  Widget _bottom() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: GestureDetector(
        onTap: _canStart ? _start : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 50,
          decoration: BoxDecoration(
            color: _canStart ? widget.color : AppColors.surface,
            border: Border.all(
                color: _canStart ? widget.color : AppColors.border),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(
            child: Text(
                _isSingle
                    ? 'Start Game'
                    : 'Start Game (${_selected.length}/${widget.requiredPositions})',
                style: AppText.ui(15,
                    weight: FontWeight.w700,
                    color: _canStart ? AppColors.bg : AppColors.text2)),
          ),
        ),
      ),
    );
  }
}
