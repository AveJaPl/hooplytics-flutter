import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../utils/haptics.dart';

typedef HapticFeedbackFunction = Future<void> Function();

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();

  bool _isPro = false;
  String? _selectedAvatar;
  bool _notificationsEnabled = true;
  bool _notifyWeeklySummary = true;
  bool _notifyGoalReminders = true;
  bool _notifyNewFeatures = false;
  XFile? _bugPhoto;




  // Goals
  int _weeklyMakesGoal = 200;
  int _weeklySessionGoal = 5;
  bool _streakReminder = true;

  @override
  void initState() {
    super.initState();
    _loadUserGoals();
  }


  void _loadUserGoals() {
    final user = _authService.currentUser;
    if (user != null && user.userMetadata != null) {
      final meta = user.userMetadata!;
      setState(() {
        _weeklyMakesGoal =
            (meta['weekly_makes_goal'] as int? ?? 200).clamp(100, 5000);
        _weeklySessionGoal = meta['weekly_sessions_goal'] as int? ?? 5;
        _streakReminder = meta['streak_reminder'] as bool? ?? true;
      });
    }
  }

  String get _userName {
    final user = _authService.currentUser;
    if (user == null) return 'Player';
    final meta = user.userMetadata;
    if (meta != null && meta['display_name'] != null) {
      return meta['display_name'] as String;
    }
    return user.email?.split('@').first ?? 'Player';
  }

  double _goalToIndex(int goal) {
    if (goal <= 500) return (goal - 100) / 10.0;
    if (goal <= 1000) return 40.0 + (goal - 500) / 20.0;
    if (goal <= 2000) return 65.0 + (goal - 1000) / 50.0;
    return 85.0 + (goal - 2000) / 200.0;
  }

  int _indexToGoal(double index) {
    if (index <= 40) return (100 + index * 10).round();
    if (index <= 65) return (500 + (index - 40) * 20).round();
    if (index <= 85) return (1000 + (index - 65) * 50).round();
    return (2000 + (index - 85) * 200).round();
  }

  // ── Bottom sheets (unchanged logic) ───────────────────────────────────────

  void _showEditProfile() {
    final ctrl = TextEditingController(text: _userName);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 40),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Text('EDIT PROFILE',
                  style: AppText.ui(14,
                      color: AppColors.text2,
                      letterSpacing: 1.2,
                      weight: FontWeight.w800)),
              const SizedBox(height: 20),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: AppText.ui(16, color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nickname',
                  labelStyle: TextStyle(color: AppColors.text3),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.gold)),
                ),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () async {
                  Haptics.mediumImpact();
                  final nav = Navigator.of(context);
                  try {
                    await _authService
                        .updateUserMetadata({'display_name': ctrl.text});
                    if (mounted) {
                      setState(() {});
                      nav.pop();
                    }
                  } catch (e) {
                    debugPrint('$e');
                  }
                },
                child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(14)),
                    child: Center(
                        child: Text('Save Changes',
                            style: AppText.ui(16,
                                weight: FontWeight.w700,
                                color: AppColors.bg)))),
              ),
            ]),
      ),
    );
  }

  void _showAvatarPicker() {
    final avatars =
        List.generate(2, (i) => 'assets/avatars/avatar_${i + 1}.png');
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CHOOSE AVATAR',
                  style: AppText.ui(14,
                      color: AppColors.text2,
                      letterSpacing: 1.2,
                      weight: FontWeight.w800)),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: avatars.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16),
                itemBuilder: (context, i) {
                  final path = avatars[i];
                  final selected = _selectedAvatar == path;
                  return GestureDetector(
                    onTap: () {
                      Haptics.lightImpact();
                      setState(() => _selectedAvatar = path);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: selected
                                  ? AppColors.gold
                                  : Colors.transparent,
                              width: 3)),
                      child: CircleAvatar(
                        backgroundColor: AppColors.bg,
                        backgroundImage: AssetImage(path),
                        onBackgroundImageError: (_, __) {},
                        child: !selected
                            ? const Icon(Icons.person, color: AppColors.text3)
                            : null,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
            ]),
      ),
    );
  }

  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PRIVACY POLICY',
              style: AppText.ui(14,
                  color: AppColors.text2,
                  letterSpacing: 1.2,
                  weight: FontWeight.w800)),
          const SizedBox(height: 20),
          Expanded(
              child: SingleChildScrollView(
                  child: Text(
                      'Your privacy is important to us. Hooplytics collects data about your shooting sessions to provide performance analytics.\n\n'
                      '1. Data Collection: We store your session data, including makes, misses, and shot locations.\n'
                      '2. Account Data: If you create an account, we store your email and nickname.\n'
                      '3. Usage: Data is used only for personal statistics and app improvement.\n'
                      '4. Security: We use industry-standard encryption to protect your data.\n\n'
                      'By using this app, you agree to the terms of this policy.',
                      style: AppText.ui(14, color: AppColors.text1)))),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
                height: 54,
                width: double.infinity,
                decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(14)),
                child: Center(
                    child: Text('Close',
                        style: AppText.ui(16,
                            weight: FontWeight.w700, color: AppColors.bg)))),
          ),
        ]),
      ),
    );
  }

  void _showNotificationSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NOTIFICATIONS',
                    style: AppText.ui(14,
                        color: AppColors.text2,
                        letterSpacing: 1.2,
                        weight: FontWeight.w800)),
                const SizedBox(height: 16),
                _modalToggle('Master Notifications', _notificationsEnabled,
                    (v) {
                  setModal(() => _notificationsEnabled = v);
                  setState(() => _notificationsEnabled = v);
                }),
                const Divider(color: AppColors.border, height: 24),
                Opacity(
                  opacity: _notificationsEnabled ? 1.0 : 0.4,
                  child: Column(children: [
                    _modalToggle(
                        'Weekly Summary',
                        _notifyWeeklySummary,
                        _notificationsEnabled
                            ? (v) {
                                setModal(() => _notifyWeeklySummary = v);
                                setState(() => _notifyWeeklySummary = v);
                              }
                            : null),
                    _modalToggle(
                        'Goal Reminders',
                        _notifyGoalReminders,
                        _notificationsEnabled
                            ? (v) {
                                setModal(() => _notifyGoalReminders = v);
                                setState(() => _notifyGoalReminders = v);
                              }
                            : null),
                    _modalToggle(
                        'New Features',
                        _notifyNewFeatures,
                        _notificationsEnabled
                            ? (v) {
                                setModal(() => _notifyNewFeatures = v);
                                setState(() => _notifyNewFeatures = v);
                              }
                            : null),
                    _modalToggle(
                        'Streak at Risk',
                        _streakReminder,
                        _notificationsEnabled
                            ? (v) {
                                setModal(() => _streakReminder = v);
                                setState(() => _streakReminder = v);
                              }
                            : null),
                  ]),
                ),
                const SizedBox(height: 20),
              ]),
        ),
      ),
    );
  }

  Widget _modalToggle(String title, bool value, Function(bool)? onChange) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title,
              style:
                  AppText.ui(15, color: Colors.white, weight: FontWeight.w500)),
          Switch(
              value: value,
              onChanged: onChange,
              activeThumbColor: AppColors.gold,
              activeTrackColor: AppColors.gold.withValues(alpha: 0.3)),
        ]),
      );

  void _showReportBugForm() {
    final ctrl = TextEditingController();
    _bugPhoto = null;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 40),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 24),
                Row(children: [
                  const Text('🐛', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Text('REPORT A BUG',
                      style: AppText.ui(14,
                          color: AppColors.text2,
                          letterSpacing: 1.2,
                          weight: FontWeight.w800)),
                ]),
                const SizedBox(height: 12),
                Text('Something went wrong? Describe what happened.',
                    style: AppText.ui(13, color: AppColors.text3)),
                const SizedBox(height: 20),
                TextField(
                  controller: ctrl,
                  maxLines: 4,
                  style: AppText.ui(15, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'What happened?',
                    hintStyle: TextStyle(
                        color: AppColors.text3.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: AppColors.bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final photo =
                          await picker.pickImage(source: ImageSource.gallery);
                      if (photo != null) setModal(() => _bugPhoto = photo);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.28)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.camera_alt_rounded,
                            color: AppColors.gold, size: 18),
                        const SizedBox(width: 7),
                        Text('Add Photo',
                            style: AppText.ui(13,
                                color: AppColors.gold,
                                weight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                  if (_bugPhoto != null) ...[
                    const SizedBox(width: 14),
                    Stack(children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                          image: DecorationImage(
                              image: FileImage(File(_bugPhoto!.path)),
                              fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                          top: -8,
                          right: -8,
                          child: GestureDetector(
                            onTap: () => setModal(() => _bugPhoto = null),
                            child: const CircleAvatar(
                                radius: 10,
                                backgroundColor: AppColors.red,
                                child: Icon(Icons.close,
                                    size: 12, color: Colors.white)),
                          )),
                    ]),
                  ],
                ]),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: () {
                    Haptics.mediumImpact();
                    if (ctrl.text.trim().isNotEmpty) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Report sent!',
                            style: AppText.ui(14, weight: FontWeight.w600)),
                        backgroundColor: AppColors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ));
                    }
                  },
                  child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ]),
                      child: Center(
                          child: Text('Send Report',
                              style: AppText.ui(16,
                                  weight: FontWeight.w700,
                                  color: AppColors.bg)))),
                ),
              ]),
        ),
      ),
    );
  }

  void _showSubscriptionPortal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _SubscriptionPortal(onSuccess: () {
        setState(() => _isPro = true);
        Navigator.pop(context);
      }),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          _topBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              physics: const BouncingScrollPhysics(),
              children: [
                // ── Profile card ─────────────────────────────────────────
                _profileCard(),
                const SizedBox(height: 20),

                // ── Pro upsell (only if not pro) ─────────────────────────
                if (!_isPro) ...[_proCard(), const SizedBox(height: 32)],


                // ── Preferences section ──────────────────────────────────
                _sectionLabel('PREFERENCES'),
                _tile(
                  icon: Icons.vibration_rounded,
                  label: 'Haptic Feedback',
                  isToggle: true,
                  toggleValue: Haptics.enabled,
                  onTap: () async {
                    final newVal = !Haptics.enabled;
                    setState(() => Haptics.enabled = newVal);
                    if (newVal) Haptics.lightImpact();
                    await _authService
                        .updateUserMetadata({'haptics_enabled': newVal});
                  },
                ),
                const SizedBox(height: 24),

                // ── Goals section ────────────────────────────────────────
                _sectionLabel('GOALS'),
                _goalTile(
                  icon: Icons.flag_rounded,
                  label: 'Training Goals',
                  value:
                      '$_weeklyMakesGoal makes · $_weeklySessionGoal sessions/wk',
                  onTap: () => _showGoalsSheet(),
                ),
                const SizedBox(height: 24),

                // ── Support section ──────────────────────────────────────
                _sectionLabel('LEGAL & SUPPORT'),
                _tile(
                  icon: Icons.lock_outline_rounded,
                  label: 'Privacy & Security',
                  onTap: _showPrivacyPolicy,
                ),
                _tile(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notifications',
                  onTap: _showNotificationSettings,
                ),
                _tile(
                  icon: Icons.bug_report_outlined,
                  label: 'Report a Bug',
                  onTap: _showReportBugForm,
                ),
                const SizedBox(height: 32),

                // ── Danger zone ──────────────────────────────────────────
                _sectionLabel('DANGER ZONE'),
                _dangerTile(
                  icon: Icons.logout_rounded,
                  label: 'Log Out',
                  color: AppColors.text1,
                  onTap: () async {
                    await AuthService().signOut();
                  },
                ),
                _dangerTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete Account',
                  color: AppColors.red,
                  onTap: () {},
                ),
                const SizedBox(height: 32),

                Center(
                    child: Text('Hooplytics v1.0.0',
                        style: AppText.ui(12, color: AppColors.text3))),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TOP BAR — unchanged from original
  // ══════════════════════════════════════════════════════════════════════════

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PROFILE',
                style: AppText.ui(11,
                    color: AppColors.text2,
                    letterSpacing: 1.4,
                    weight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('Your Account', style: AppText.ui(24, weight: FontWeight.w800)),
          ]),
          const Spacer(),
        ]),
      );

  // ══════════════════════════════════════════════════════════════════════════
  //  PROFILE CARD  — avatar + name + badge, styled like Train featured card
  // ══════════════════════════════════════════════════════════════════════════

  Widget _profileCard() {
    final initials = _userName.trim().isEmpty
        ? '?'
        : _userName
            .trim()
            .split(' ')
            .take(2)
            .map((e) => e.isEmpty ? '' : e[0].toUpperCase())
            .join();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
            color: _isPro
                ? AppColors.gold.withValues(alpha: 0.3)
                : AppColors.border),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          if (_isPro)
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        // Avatar + Edit
        GestureDetector(
          onTap: _showAvatarPicker,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    AppColors.surfaceHi,
                    AppColors.bg,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                    color: _isPro
                        ? AppColors.gold.withValues(alpha: 0.5)
                        : AppColors.border,
                    width: 2),
                image: _selectedAvatar != null
                    ? DecorationImage(
                        image: AssetImage(_selectedAvatar!), fit: BoxFit.cover)
                    : null,
                boxShadow: [
                  if (_isPro)
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.2),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: _selectedAvatar == null
                  ? Center(
                      child: Text(initials,
                          style: AppText.display(28,
                              color: _isPro ? AppColors.gold : AppColors.text2)))
                  : null,
            ),
            // Edit badge
            Positioned(
                right: -2,
                bottom: -2,
                child: GestureDetector(
                  onTap: _showAvatarPicker,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold,
                      border: Border.all(color: AppColors.bg, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                        )
                      ],
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 13, color: AppColors.bg),
                  ),
                )),
          ]),
        ),
        const SizedBox(width: 20),
        // Info
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_userName,
              style: AppText.ui(22,
                  weight: FontWeight.w800, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          _isPro ? _proBadge() : _localBadge(),
        ])),
        // Fixed Edit button
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _showEditProfile,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceHi,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.edit_note_rounded,
                size: 20, color: AppColors.gold),
          ),
        ),
      ]),
    );
  }

  Widget _localBadge() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.text3.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('Local Account',
          style:
              AppText.ui(11, weight: FontWeight.w600, color: AppColors.text2)));

  Widget _proBadge() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.40)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.star_rounded, color: AppColors.gold, size: 12),
        const SizedBox(width: 4),
        Text('Pro Member',
            style:
                AppText.ui(11, weight: FontWeight.w700, color: AppColors.gold)),
      ]));

  // ══════════════════════════════════════════════════════════════════════════
  //  PRO UPSELL CARD  — refined, not banner-ad loud
  // ══════════════════════════════════════════════════════════════════════════

  Widget _proCard() => GestureDetector(
        onTap: _showSubscriptionPortal,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.gold, AppColors.goldMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.30),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 5))
            ],
          ),
          child: Row(children: [
            const Icon(Icons.auto_awesome_rounded,
                color: AppColors.bg, size: 32),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('GO PRO ACCESS',
                      style: AppText.ui(16,
                          weight: FontWeight.w900, color: AppColors.bg)),
                  Text('Cloud sync, AI analysis & more',
                      style: AppText.ui(12,
                          weight: FontWeight.w600,
                          color: AppColors.bg.withValues(alpha: 0.70))),
                ])),
            const Icon(Icons.chevron_right_rounded, color: AppColors.bg),
          ]),
        ),
      );

  // ══════════════════════════════════════════════════════════════════════════
  //  SECTION LABEL  — matches Train screen style (text + horizontal rule)
  // ══════════════════════════════════════════════════════════════════════════

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

  // ══════════════════════════════════════════════════════════════════════════
  //  SETTINGS TILE  — left colour accent line + icon + label
  // ══════════════════════════════════════════════════════════════════════════

  Widget _tile({
    required IconData icon,
    required String label,
    bool isToggle = false,
    bool toggleValue = false,
    bool badge = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          // Icon container — matches Train list card style
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 18, color: AppColors.text2),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Text(label,
                  style: AppText.ui(15,
                      weight: FontWeight.w500, color: Colors.white))),
          if (badge)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 10),
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.gold),
            ),
          if (isToggle)
            SizedBox(
                height: 24,
                child: Switch(
                    value: toggleValue,
                    onChanged: (_) => onTap(),
                    activeThumbColor: AppColors.gold,
                    activeTrackColor: AppColors.gold.withValues(alpha: 0.28),
                    inactiveThumbColor: AppColors.text3,
                    inactiveTrackColor: AppColors.bg))
          else
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.text3, size: 18),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GOAL TILE  — same visual as settings tile but with value label
  // ══════════════════════════════════════════════════════════════════════════

  Widget _goalTile({
    required IconData icon,
    required String label,
    String? value,
    bool isToggle = false,
    bool toggleValue = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 18, color: AppColors.gold),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                Text(label,
                    style: AppText.ui(15,
                        weight: FontWeight.w500, color: Colors.white)),
                if (!isToggle && value != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(value,
                        style: AppText.ui(13,
                            color: AppColors.gold, weight: FontWeight.w600)),
                  ),
              ])),
          if (isToggle)
            SizedBox(
                height: 24,
                child: Switch(
                  value: toggleValue,
                  onChanged: (_) => onTap(),
                  activeThumbColor: AppColors.gold,
                  activeTrackColor: AppColors.gold.withValues(alpha: 0.28),
                  inactiveThumbColor: AppColors.text3,
                  inactiveTrackColor: AppColors.bg,
                ))
          else if (value != null)
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.text3, size: 18),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GOALS SHEET  — sliders + toggles for all user targets
  // ══════════════════════════════════════════════════════════════════════════

  void _showGoalsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModal) {
          void save() async {
            // Optimistic update
            setState(() {});

            try {
              await _authService.updateUserMetadata({
                'weekly_makes_goal': _weeklyMakesGoal,
                'weekly_sessions_goal': _weeklySessionGoal,
                'streak_reminder': _streakReminder,
              });
            } catch (e) {
              debugPrint('Failed to sync goals: $e');
            }

            if (!modalCtx.mounted) return;
            Navigator.pop(modalCtx);
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
                24, 20, 24, MediaQuery.of(modalCtx).viewInsets.bottom + 32),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 24),

                  // Header
                  Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.flag_rounded,
                          color: AppColors.gold, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('YOUR GOALS',
                              style: AppText.ui(14,
                                  color: AppColors.text2,
                                  letterSpacing: 1.2,
                                  weight: FontWeight.w800)),
                          Text('Set your weekly targets',
                              style: AppText.ui(12, color: AppColors.text3)),
                        ]),
                  ]),
                  const SizedBox(height: 28),

                  // ── Weekly Makes ─────────────────────────────────────────────
                  _GoalSliderRow(
                    label: 'Weekly Makes Goal',
                    icon: Icons.sports_basketball_outlined,
                    value: _goalToIndex(_weeklyMakesGoal).toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    minLabel: '100',
                    maxLabel: '5000',
                    displayValue: '$_weeklyMakesGoal makes',
                    onChanged: (v) {
                      final goal = _indexToGoal(v);
                      setModal(() => _weeklyMakesGoal = goal);
                      setState(() => _weeklyMakesGoal = goal);
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── Sessions per week ─────────────────────────────────────────
                  _GoalSliderRow(
                    label: 'Sessions per Week',
                    icon: Icons.calendar_today_outlined,
                    value: _weeklySessionGoal.toDouble(),
                    min: 1,
                    max: 14,
                    divisions: 13,
                    displayValue:
                        '$_weeklySessionGoal ${_weeklySessionGoal == 1 ? "session" : "sessions"}',
                    onChanged: (v) {
                      setModal(() => _weeklySessionGoal = v.round());
                      setState(() => _weeklySessionGoal = v.round());
                    },
                  ),
                  const SizedBox(height: 28),

                  // Save
                  GestureDetector(
                    onTap: save,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Center(
                          child: Text('Save Goals',
                              style: AppText.ui(15,
                                  weight: FontWeight.w700,
                                  color: AppColors.bg))),
                    ),
                  ),
                ]),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DANGER TILE  — flat, no red border container — cleaner
  // ══════════════════════════════════════════════════════════════════════════

  Widget _dangerTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        Haptics.mediumImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(
              color: color == AppColors.red
                  ? AppColors.red.withValues(alpha: 0.22)
                  : AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.20)),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Text(label,
              style: AppText.ui(15, weight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

}

// ══════════════════════════════════════════════════════════════════════════════
//  GOAL SLIDER ROW  — label + slider + live value
// ══════════════════════════════════════════════════════════════════════════════

class _GoalSliderRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value, min, max;
  final int divisions;
  final String displayValue;
  final String? minLabel, maxLabel;
  final ValueChanged<double> onChanged;

  const _GoalSliderRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displayValue,
    this.minLabel,
    this.maxLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Label row
      Row(children: [
        Icon(icon, size: 15, color: AppColors.text2),
        const SizedBox(width: 8),
        Text(label,
            style: AppText.ui(13,
                color: AppColors.text2, weight: FontWeight.w600)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
          ),
          child: Text(displayValue,
              style: AppText.ui(12,
                  weight: FontWeight.w700, color: AppColors.gold)),
        ),
      ]),
      const SizedBox(height: 10),
      // Slider
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor: AppColors.gold,
          inactiveTrackColor: AppColors.borderSub,
          thumbColor: AppColors.gold,
          overlayColor: AppColors.gold.withValues(alpha: 0.16),
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        ),
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
      // Min / max labels
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          Text(minLabel ?? '${min.round()}',
              style: AppText.ui(11, color: AppColors.text3)),
          const Spacer(),
          Text(maxLabel ?? '${max.round()}',
              style: AppText.ui(11, color: AppColors.text3)),
        ]),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SUBSCRIPTION PORTAL  — unchanged logic
// ══════════════════════════════════════════════════════════════════════════════

class _SubscriptionPortal extends StatelessWidget {
  final VoidCallback onSuccess;
  const _SubscriptionPortal({required this.onSuccess});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 40),
        const Icon(Icons.workspace_premium_rounded,
            color: AppColors.gold, size: 72),
        const SizedBox(height: 24),
        Text('Unlock Everything',
            style:
                AppText.ui(24, weight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 8),
        Text('Master your shots with advanced features',
            style: AppText.ui(14, color: AppColors.text2)),
        const SizedBox(height: 40),
        _featureRow(Icons.cloud_sync_rounded, 'Full Cloud Sync (Supabase)'),
        _featureRow(Icons.analytics_outlined, 'Advanced Shooting Heatmaps'),
        _featureRow(Icons.videocam_outlined, 'Future AI Shot Analysis'),
        const Spacer(),
        GestureDetector(
          onTap: () {
            Haptics.heavyImpact();
            onSuccess();
          },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 5))
              ],
            ),
            child: Center(
                child: Text('Subscribe · 19.99 PLN / mo',
                    style: AppText.ui(16,
                        weight: FontWeight.w800, color: AppColors.bg))),
          ),
        ),
        const SizedBox(height: 32),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Maybe later',
                style: AppText.ui(14, color: AppColors.text2))),
        const SizedBox(height: 10),
      ]),
    );
  }

  Widget _featureRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppColors.gold, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Text(text,
                  style: AppText.ui(15,
                      weight: FontWeight.w500, color: Colors.white))),
        ]),
      );
}
