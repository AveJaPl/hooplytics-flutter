import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  bool _isLogin = true;
  final _authService = AuthService();

  void _switchTab(bool login) {
    if (_isLogin == login) return;
    setState(() => _isLogin = login);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppText.ui(14)),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showInfo(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppText.ui(14)),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _goToDashboard() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const DashboardScreen(),
        transitionDuration: const Duration(milliseconds: 450),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      await _authService.signInWithGoogle();
      _goToDashboard();
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Błąd logowania Google.');
    }
  }

  Future<void> _handleAppleSignIn() async {
    try {
      await _authService.signInWithApple();
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Błąd logowania Apple.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    final slide = Tween(
      begin: 20.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const _AuthBg(),
          SafeArea(
            child: AnimatedBuilder(
              animation: _entryCtrl,
              builder: (_, child) => FadeTransition(
                opacity: fade,
                child: Transform.translate(
                  offset: Offset(0, slide.value),
                  child: child,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 56),
                    _buildBrand(),
                    const SizedBox(height: 52),
                    _buildTabRow(),
                    const SizedBox(height: 36),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: _isLogin
                          ? _LoginForm(
                              key: const ValueKey('login'),
                              onSuccess: _goToDashboard,
                              onError: _showError,
                              onInfo: _showInfo,
                            )
                          : _RegisterForm(
                              key: const ValueKey('register'),
                              onSuccess: _goToDashboard,
                              onError: _showError,
                              onInfo: _showInfo,
                            ),
                    ),
                    const SizedBox(height: 40),
                    _buildDivider(),
                    const SizedBox(height: 28),
                    _buildSocialRow(),
                    const SizedBox(height: 52),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border, width: 1),
            borderRadius: BorderRadius.circular(10),
            color: AppColors.surface,
          ),
          child: Center(
            child: Text('H', style: AppText.display(22, color: AppColors.gold)),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          _isLogin ? 'Welcome\nback.' : 'Join\nthe game.',
          style: AppText.display(44, color: AppColors.text1),
        ),
        const SizedBox(height: 10),
        Text(
          _isLogin
              ? 'Sign in to track your progress.'
              : 'Create an account to get started.',
          style: AppText.ui(15, color: AppColors.text2),
        ),
      ],
    );
  }

  Widget _buildTabRow() {
    return Row(
      children: [
        _TabButton(
          label: 'Sign In',
          active: _isLogin,
          onTap: () => _switchTab(true),
        ),
        const SizedBox(width: 24),
        _TabButton(
          label: 'Register',
          active: !_isLogin,
          onTap: () => _switchTab(false),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.borderSub)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: AppText.ui(11, color: AppColors.text3, letterSpacing: 2),
          ),
        ),
        Expanded(child: Container(height: 1, color: AppColors.borderSub)),
      ],
    );
  }

  Widget _buildSocialRow() {
    return Row(
      children: [
        Expanded(
          child: _SocialBtn(
            label: 'Apple',
            icon: Icons.apple_rounded,
            onTap: _handleAppleSignIn,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _SocialBtn(
            label: 'Google',
            icon: Icons.g_mobiledata_rounded,
            onTap: _handleGoogleSignIn,
          ),
        ),
      ],
    );
  }
}

// ─── Tab Button ───────────────────────────────────────────────────────────────

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppText.ui(
                16,
                weight: FontWeight.w600,
                color: active ? AppColors.text1 : AppColors.text3,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 2,
              width: active ? 28.0 : 0.0,
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Login Form ───────────────────────────────────────────────────────────────

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

  Future<void> _submit() async {
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
    } catch (_) {
      widget.onError('Wystąpił błąd. Spróbuj ponownie.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      widget.onError('Wpisz email, aby zresetować hasło.');
      return;
    }
    try {
      await _authService.resetPassword(email);
      widget.onInfo('Link do resetu hasła wysłany na $email');
    } on AuthException catch (e) {
      widget.onError(e.message);
    } catch (_) {
      widget.onError('Nie udało się wysłać linku.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Field(
          label: 'EMAIL',
          hint: 'you@example.com',
          type: TextInputType.emailAddress,
          controller: _emailCtrl,
        ),
        const SizedBox(height: 20),
        _Field(
          label: 'PASSWORD',
          hint: '••••••••••',
          obscure: _obscure,
          controller: _passwordCtrl,
          trailing: GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Icon(
              _obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
              color: AppColors.text3,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: _handleForgotPassword,
            child: Text(
              'Forgot password?',
              style: AppText.ui(
                13,
                color: AppColors.gold,
                weight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        _PrimaryBtn(label: 'Sign In', loading: _loading, onTap: _submit),
      ],
    );
  }
}

// ─── Register Form ────────────────────────────────────────────────────────────

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

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      widget.onError('Wypełnij wszystkie pola.');
      return;
    }

    if (_strength.score < 2) {
      widget.onError(
        'Hasło za słabe. Min. 6 znaków + wielka litera lub cyfra.',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _authService.signUpWithEmail(email, password, name);
      widget.onInfo('Konto utworzone! Sprawdź email.');
    } on AuthException catch (e) {
      widget.onError(e.message);
    } catch (_) {
      widget.onError('Wystąpił błąd. Spróbuj ponownie.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Field(label: 'FULL NAME', hint: 'Jan Kowalski', controller: _nameCtrl),
        const SizedBox(height: 20),
        _Field(
          label: 'EMAIL',
          hint: 'you@example.com',
          type: TextInputType.emailAddress,
          controller: _emailCtrl,
        ),
        const SizedBox(height: 20),
        _Field(
          label: 'PASSWORD',
          hint: '••••••••••',
          obscure: _obscure,
          controller: _passwordCtrl,
          trailing: GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Icon(
              _obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
              color: AppColors.text3,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _PasswordStrengthBar(strength: _strength),
        const SizedBox(height: 32),
        _PrimaryBtn(label: 'Create Account', loading: _loading, onTap: _submit),
      ],
    );
  }
}

// ─── Password Strength Bar ────────────────────────────────────────────────────

class _PasswordStrengthBar extends StatelessWidget {
  final PasswordStrength strength;
  const _PasswordStrengthBar({required this.strength});

  @override
  Widget build(BuildContext context) {
    if (strength.level == PasswordStrengthLevel.none)
      return const SizedBox.shrink();

    return Row(
      children: [
        ...List.generate(4, (i) {
          final active = i < strength.score;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                color: active ? strength.color : AppColors.borderSub,
              ),
            ),
          );
        }),
        const SizedBox(width: 12),
        Text(
          strength.label,
          style: AppText.ui(11, color: strength.color, weight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ─── Shared Form Widgets ──────────────────────────────────────────────────────

class _Field extends StatefulWidget {
  final String label, hint;
  final bool obscure;
  final TextInputType? type;
  final Widget? trailing;
  final TextEditingController? controller;
  const _Field({
    required this.label,
    required this.hint,
    this.obscure = false,
    this.type,
    this.trailing,
    this.controller,
  });
  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppText.ui(
            10,
            weight: FontWeight.w600,
            color: _focused ? AppColors.gold : AppColors.text3,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(
                color: _focused ? AppColors.gold : AppColors.border,
                width: _focused ? 1.5 : 1.0,
              ),
            ),
          ),
          child: Focus(
            onFocusChange: (v) => setState(() => _focused = v),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    obscureText: widget.obscure,
                    keyboardType: widget.type,
                    style: AppText.ui(15, weight: FontWeight.w400),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: AppText.ui(15, color: AppColors.text3),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      isDense: true,
                    ),
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 8),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _PrimaryBtn({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: loading ? AppColors.goldMid : AppColors.gold,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.bg,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      label,
                      style: AppText.ui(
                        14,
                        weight: FontWeight.w700,
                        color: AppColors.bg,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SocialBtn({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppColors.text2),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppText.ui(
                  14,
                  weight: FontWeight.w500,
                  color: AppColors.text2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthBg extends StatelessWidget {
  const _AuthBg();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: _AuthBgPainter(),
    );
  }
}

class _AuthBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final topGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.gold.withValues(alpha: 0.07),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width, 0),
              radius: size.width * 0.7,
            ),
          );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), topGlow);
  }

  @override
  bool shouldRepaint(_) => false;
}
