import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();

  // Symulacja danych użytkownika (docelowo z bazy/Providera)
  bool _isPro = false;
  String? _selectedAvatar;
  String _voiceLanguage = 'Polski';

  String get _userName {
    final user = _authService.currentUser;
    if (user == null) return 'Player';
    final meta = user.userMetadata;
    if (meta != null && meta['display_name'] != null) {
      return meta['display_name'] as String;
    }
    return user.email?.split('@').first ?? 'Player';
  }

  void _showEditProfile() {
    final TextEditingController nameController =
        TextEditingController(text: _userName);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Text('EDIT PROFILE',
                style: AppText.ui(12,
                    color: AppColors.text3,
                    letterSpacing: 1.5,
                    weight: FontWeight.w700)),
            const SizedBox(height: 20),

            // Nickname Input
            TextField(
              controller: nameController,
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

            // Save Button
            GestureDetector(
              onTap: () async {
                HapticFeedback.mediumImpact();
                final navigator = Navigator.of(context);
                try {
                  await _authService.updateUserMetadata(
                      {'display_name': nameController.text});
                  if (mounted) {
                    setState(() {});
                    navigator.pop();
                  }
                } catch (e) {
                  debugPrint('Update profile error: $e');
                  // Optional: show error toast/banner
                }
              },
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text('Save Changes',
                      style: AppText.ui(16,
                          weight: FontWeight.w700, color: AppColors.bg)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarPicker() {
    // Lista placeholderowych nazw plików. Użytkownik podstawi tu rzeczywiste nazwy.
    final List<String> avatars =
        List.generate(2, (index) => 'assets/avatars/avatar_${index + 1}.png');

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WYBIERZ ZDJĘCIE PROFILOWE',
                style: AppText.ui(12,
                    color: AppColors.text3,
                    letterSpacing: 1.5,
                    weight: FontWeight.w700)),
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: avatars.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemBuilder: (context, index) {
                final String avatarPath = avatars[index];
                final bool isSelected = _selectedAvatar == avatarPath;

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedAvatar = avatarPath);
                    Navigator.pop(context);
                    HapticFeedback.mediumImpact();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.gold : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: AppColors.bg,
                      // Placeholder do czasu aż uzytkownik wgra pliki "avatar_1.png" etc:
                      backgroundImage: AssetImage(avatarPath),
                      onBackgroundImageError: (exception, stackTrace) {
                        // Cicha obsługa błędów, by aplikacja nie crashowała jeśli plik nie istnieje
                      },
                      child: _selectedAvatar != avatarPath
                          ? const Icon(Icons.person, color: AppColors.text3)
                          : null,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('VOICE LANGUAGE',
                style: AppText.ui(12,
                    color: AppColors.text3,
                    letterSpacing: 1.5,
                    weight: FontWeight.w700)),
            const SizedBox(height: 20),
            _buildLanguageOption('Polski'),
            _buildLanguageOption('English'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String lang) {
    final bool isSelected = _voiceLanguage == lang;
    return InkWell(
      onTap: () {
        setState(() => _voiceLanguage = lang);
        Navigator.pop(context);
        HapticFeedback.lightImpact();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Text(lang,
                style: AppText.ui(16,
                    color: isSelected ? AppColors.gold : Colors.white,
                    weight: isSelected ? FontWeight.w700 : FontWeight.w500)),
            if (isSelected) const Spacer(),
            if (isSelected)
              const Icon(Icons.check_rounded, color: AppColors.gold),
          ],
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
      builder: (context) => _SubscriptionPortal(onSuccess: () {
        setState(() => _isPro = true);
        Navigator.pop(context);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 20),
                  _buildSubscriptionCard(), // Nowa sekcja subskrypcji
                  const SizedBox(height: 32),

                  _buildSectionHeader('ACCOUNT'),
                  _buildSettingsTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Edit Profile',
                    onTap: _showEditProfile,
                  ),
                  _buildSettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Privacy & Security',
                    onTap: () {},
                  ),
                  const SizedBox(height: 24),

                  _buildSectionHeader('PREFERENCES'),
                  _buildSettingsTile(
                    icon: Icons.mic_none_rounded,
                    title: 'Voice Mode Language',
                    value: _voiceLanguage,
                    onTap: _showLanguagePicker,
                  ),
                  _buildSettingsTile(
                    icon: Icons.vibration_rounded,
                    title: 'Haptic Feedback',
                    isToggle: true,
                    toggleValue: true,
                    onTap: () {},
                  ),
                  const SizedBox(height: 24),

                  _buildSectionHeader('SUPPORT & COMMUNITY'),
                  _buildSettingsTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    hasBadge: true,
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    icon: Icons.bug_report_outlined,
                    title: 'Report a Bug',
                    onTap: () {},
                  ),
                  const SizedBox(height: 32),

                  _buildDangerZone(),
                  const SizedBox(height: 40),

                  Center(
                    child: Text(
                      'Hooplytics v1.0.0',
                      style: AppText.ui(12, color: AppColors.text3),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ACCOUNT',
                style: AppText.ui(10,
                    color: AppColors.text3,
                    letterSpacing: 1.8,
                    weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('Profile', style: AppText.ui(24, weight: FontWeight.w800)),
          ]),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _buildAvatar(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: AppText.ui(20,
                      weight: FontWeight.w700, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                _isPro ? _buildProBadge() : _buildLocalBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    // Pobieranie inicjałów z nazwy (do 2 liter)
    String initials = _userName.trim().isNotEmpty
        ? _userName
            .trim()
            .split(' ')
            .take(2)
            .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
            .join()
        : '?';

    return GestureDetector(
      onTap: _showAvatarPicker,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _selectedAvatar == null
              ? AppColors.gold.withValues(alpha: 0.15)
              : null,
          border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.5), width: 2),
          image: _selectedAvatar != null
              ? DecorationImage(
                  image: AssetImage(_selectedAvatar!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: _selectedAvatar == null
            ? Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildLocalBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.text3.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Local Account',
        style: AppText.ui(11, weight: FontWeight.w600, color: AppColors.text2),
      ),
    );
  }

  Widget _buildProBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border:
            Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.gold, size: 12),
          const SizedBox(width: 4),
          Text(
            'Pro Member',
            style:
                AppText.ui(11, weight: FontWeight.w700, color: AppColors.gold),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    if (_isPro) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _showSubscriptionPortal,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.gold, AppColors.gold.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: 2)
          ],
        ),
        child: Row(
          children: [
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
                          color: AppColors.bg.withValues(alpha: 0.8))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.bg),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: AppText.ui(11,
            color: AppColors.text3,
            letterSpacing: 1.5,
            weight: FontWeight.w700),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? value,
    bool isToggle = false,
    bool toggleValue = false,
    bool hasBadge = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.text2, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: AppText.ui(15,
                    weight: FontWeight.w500, color: Colors.white),
              ),
            ),
            if (hasBadge)
              Container(
                margin: const EdgeInsets.only(right: 8),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
            if (value != null)
              Text(
                value,
                style: AppText.ui(14, color: AppColors.text3),
              ),
            if (isToggle)
              SizedBox(
                height: 24,
                child: Switch(
                  value: toggleValue,
                  onChanged: (val) {},
                  activeThumbColor: AppColors.gold,
                  activeTrackColor: AppColors.gold.withValues(alpha: 0.3),
                  inactiveThumbColor: AppColors.text3,
                  inactiveTrackColor: AppColors.bg,
                ),
              )
            else if (value == null)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.text3, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _buildActionTile(
            title: 'Log Out',
            icon: Icons.logout_rounded,
            color: Colors.white,
            onTap: () async {
              await AuthService().signOut();
            },
          ),
          const Divider(height: 1, color: AppColors.border, indent: 48),
          _buildActionTile(
            title: 'Delete Account',
            icon: Icons.delete_outline_rounded,
            color: Colors.redAccent,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(
              title,
              style: AppText.ui(15, weight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Portal Subskrypcji (Bottom Sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _SubscriptionPortal extends StatelessWidget {
  final VoidCallback onSuccess;
  const _SubscriptionPortal({required this.onSuccess});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 40),
          const Icon(Icons.workspace_premium_rounded,
              color: AppColors.gold, size: 80),
          const SizedBox(height: 24),
          Text('Unlock Everything',
              style:
                  AppText.ui(24, weight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 12),
          Text('Master your shots with advanced features',
              style: AppText.ui(14, color: AppColors.text3)),
          const SizedBox(height: 40),
          _featureRow(Icons.cloud_sync_rounded, 'Full Cloud Sync (Supabase)'),
          _featureRow(Icons.analytics_outlined, 'Advanced Shooting Heatmaps'),
          _featureRow(Icons.videocam_outlined, 'Future AI Shot Analysis'),
          const Spacer(),
          GestureDetector(
            onTap: () {
              HapticFeedback.heavyImpact();
              onSuccess();
            },
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(16)),
              child: Center(
                  child: Text('Subscribe - 19.99 PLN / mo',
                      style: AppText.ui(16,
                          weight: FontWeight.w800, color: AppColors.bg))),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Maybe later',
                  style: AppText.ui(14, color: AppColors.text3))),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(text,
                style: AppText.ui(15,
                    weight: FontWeight.w500, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
