import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLogin = true;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _isLogin = _tabController.index == 0);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit()),
        backgroundColor: const Color(0xFFFF3B3B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit()),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _navigateToDashboard() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const DashboardScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      await _authService.signInWithGoogle();
      _navigateToDashboard();
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Błąd logowania Google: $e');
    }
  }

  Future<void> _handleAppleSignIn() async {
    try {
      await _authService.signInWithApple();
      // OAuth redirect handles navigation via AuthGate
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Błąd logowania Apple: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const _AuthBackground(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: size.height - MediaQuery.of(context).padding.top,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      _buildHeader(),
                      const SizedBox(height: 48),
                      _buildAuthCard(),
                      const SizedBox(height: 24),
                      _buildSocialSection(),
                      const SizedBox(height: 32),
                      _buildLegalText(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF8C42), Color(0xFFD94F0A)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B1A).withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.sports_basketball,
              color: Colors.white, size: 28),
        ),
        const SizedBox(height: 16),
        Text(
          'HOOPLYTICS',
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 5,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isLogin ? 'Witaj z powrotem, zawodniku' : 'Dołącz do elity rzutowej',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.4),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF12121A),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildTabBar(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _isLogin
                  ? _LoginForm(
                      key: const ValueKey('login'),
                      onSuccess: _navigateToDashboard,
                      onError: _showError,
                      onInfo: _showSuccess,
                    )
                  : _RegisterForm(
                      key: const ValueKey('register'),
                      onSuccess: _navigateToDashboard,
                      onError: _showError,
                      onInfo: _showSuccess,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0F),
          borderRadius: BorderRadius.circular(22),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B1A), Color(0xFFFF9500)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B1A).withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelStyle: GoogleFonts.outfit(
              fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.5),
          unselectedLabelStyle:
              GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 14),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.4),
          tabs: const [Tab(text: 'Logowanie'), Tab(text: 'Rejestracja')],
        ),
      ),
    );
  }

  Widget _buildSocialSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: Divider(color: Colors.white.withValues(alpha: 0.08))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'lub kontynuuj przez',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.3),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                  child: Divider(color: Colors.white.withValues(alpha: 0.08))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SocialButton(
                  icon: '🍎',
                  label: 'Apple',
                  onTap: _handleAppleSignIn,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SocialButton(
                  icon: '🔵',
                  label: 'Google',
                  onTap: _handleGoogleSignIn,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegalText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        'Kontynuując, akceptujesz naszą Politykę Prywatności i Warunki Użytkowania.',
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          fontSize: 11,
          color: Colors.white.withValues(alpha: 0.2),
          height: 1.5,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
//  Login Form
// ──────────────────────────────────────────

class _LoginForm extends StatefulWidget {
  final VoidCallback onSuccess;
  final void Function(String) onError;
  final void Function(String) onInfo;

  const _LoginForm({
    super.key,
    required this.onSuccess,
    required this.onError,
    required this.onInfo,
  });

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  final _authService = AuthService();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      widget.onError('Wypełnij wszystkie pola.');
      return;
    }

    setState(() => _loading = true);
    try {
      await _authService.signInWithEmail(email, password);
      widget.onSuccess();
    } on AuthException catch (e) {
      widget.onError(e.message);
    } catch (e) {
      widget.onError('Wystąpił błąd. Spróbuj ponownie.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      widget.onError('Wpisz adres email, aby zresetować hasło.');
      return;
    }
    try {
      await _authService.resetPassword(email);
      widget.onInfo('Link do resetu hasła wysłany na $email');
    } on AuthException catch (e) {
      widget.onError(e.message);
    } catch (e) {
      widget.onError('Nie udało się wysłać linku resetu.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthField(
            label: 'Email',
            hint: 'twoj@email.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            controller: _emailCtrl,
          ),
          const SizedBox(height: 16),
          AuthField(
            label: 'Hasło',
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscure: _obscure,
            controller: _passwordCtrl,
            suffixIcon: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white.withValues(alpha: 0.4),
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _handleForgotPassword,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Zapomniałeś hasła?',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: const Color(0xFFFF6B1A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Zaloguj się',
            loading: _loading,
            onTap: _handleLogin,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
//  Register Form
// ──────────────────────────────────────────

class _RegisterForm extends StatefulWidget {
  final VoidCallback onSuccess;
  final void Function(String) onError;
  final void Function(String) onInfo;

  const _RegisterForm({
    super.key,
    required this.onSuccess,
    required this.onError,
    required this.onInfo,
  });

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  PasswordStrength _strength = const PasswordStrength(
    level: PasswordStrengthLevel.none,
    score: 0,
  );
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(_updateStrength);
  }

  void _updateStrength() {
    setState(() {
      _strength = PasswordStrength.evaluate(_passwordCtrl.text);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      widget.onError('Wypełnij wszystkie pola.');
      return;
    }

    if (_strength.score < 2) {
      widget.onError(
          'Hasło jest za słabe. Użyj min. 6 znaków, wielkich liter i cyfr.');
      return;
    }

    setState(() => _loading = true);
    try {
      await _authService.signUpWithEmail(email, password, name);
      widget.onInfo(
          'Konto utworzone! Sprawdź email, aby potwierdzić rejestrację.');
    } on AuthException catch (e) {
      widget.onError(e.message);
    } catch (e) {
      widget.onError('Wystąpił błąd. Spróbuj ponownie.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        children: [
          AuthField(
            label: 'Imię',
            hint: 'Twoje imię',
            icon: Icons.person_outline_rounded,
            controller: _nameCtrl,
          ),
          const SizedBox(height: 16),
          AuthField(
            label: 'Email',
            hint: 'twoj@email.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            controller: _emailCtrl,
          ),
          const SizedBox(height: 16),
          AuthField(
            label: 'Hasło',
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscure: _obscure,
            controller: _passwordCtrl,
            suffixIcon: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white.withValues(alpha: 0.4),
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 12),
          PasswordStrengthIndicator(strength: _strength),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Utwórz konto',
            loading: _loading,
            onTap: _handleRegister,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
//  Shared Widgets
// ──────────────────────────────────────────

class AuthField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextEditingController? controller;

  const AuthField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType,
    this.controller,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _focused
                  ? const Color(0xFFFF6B1A).withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.08),
              width: _focused ? 1.5 : 1,
            ),
            color: const Color(0xFF0A0A0F),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF6B1A).withValues(alpha: 0.1),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Focus(
            onFocusChange: (v) => setState(() => _focused = v),
            child: TextField(
              controller: widget.controller,
              obscureText: widget.obscure,
              keyboardType: widget.keyboardType,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.2),
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  widget.icon,
                  color: _focused
                      ? const Color(0xFFFF6B1A)
                      : Colors.white.withValues(alpha: 0.3),
                  size: 20,
                ),
                suffixIcon: widget.suffixIcon,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PasswordStrengthIndicator extends StatelessWidget {
  final PasswordStrength strength;

  const PasswordStrengthIndicator({super.key, required this.strength});

  @override
  Widget build(BuildContext context) {
    if (strength.level == PasswordStrengthLevel.none) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Text(
          'Siła hasła: ',
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(width: 8),
        ...List.generate(4, (i) {
          final active = i < strength.score;
          return Container(
            margin: const EdgeInsets.only(right: 4),
            width: 28,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color:
                  active ? strength.color : Colors.white.withValues(alpha: 0.1),
            ),
          );
        }),
        const SizedBox(width: 8),
        Text(
          strength.label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: strength.color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: loading ? null : onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B1A), Color(0xFFFF9500)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B1A).withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SizedBox(
      width: size.width,
      height: size.height,
      child: CustomPaint(painter: _AuthBgPainter()),
    );
  }
}

class _AuthBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF6B1A).withValues(alpha: 0.12),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.1, size.height * 0.05),
          radius: 250,
        ),
      );
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.05), 250, glow1);

    final glow2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF9500).withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.9, size.height * 0.85),
          radius: 200,
        ),
      );
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.85), 200, glow2);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
