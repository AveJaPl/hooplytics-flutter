import 'package:flutter/material.dart';
import '../main.dart';
import 'auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _lineCtrl;
  late final AnimationController _logoCtrl;
  late final AnimationController _exitCtrl;

  late final Animation<double> _lineW;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoY;
  late final Animation<double> _subFade;
  late final Animation<double> _subY;
  late final Animation<double> _dotFade;
  late final Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();

    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _lineW = CurvedAnimation(parent: _lineCtrl, curve: Curves.easeOutCubic);

    _logoFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
      ),
    );
    _logoY = Tween(begin: 14.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    _subFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
      ),
    );
    _subY = Tween(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _dotFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    _exitFade = Tween(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    await _lineCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 80));
    await _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1600));
    await _exitCtrl.forward();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AuthGate(),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      );
    }
  }

  @override
  void dispose() {
    _lineCtrl.dispose();
    _logoCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exitCtrl,
      builder: (_, child) => Opacity(opacity: _exitFade.value, child: child),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          children: [
            const _SplashBg(),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Wordmark
                  AnimatedBuilder(
                    animation: _logoCtrl,
                    builder: (_, __) => Transform.translate(
                      offset: Offset(0, _logoY.value),
                      child: Opacity(
                        opacity: _logoFade.value,
                        child: Text(
                          'HOOPLYTICS',
                          style: AppText.display(44, color: AppColors.text1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Growing line
                  AnimatedBuilder(
                    animation: _lineCtrl,
                    builder: (_, __) => Align(
                      alignment: Alignment.center,
                      child: Container(
                        height: 1,
                        width: 200 * _lineW.value,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppColors.gold,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Tagline
                  AnimatedBuilder(
                    animation: _logoCtrl,
                    builder: (_, __) => Transform.translate(
                      offset: Offset(0, _subY.value),
                      child: Opacity(
                        opacity: _subFade.value,
                        child: Text(
                          'MAKE EVERY SHOT COUNT',
                          style: AppText.ui(
                            11,
                            weight: FontWeight.w500,
                            color: AppColors.text2,
                            letterSpacing: 3.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Bottom version text
            AnimatedBuilder(
              animation: _logoCtrl,
              builder: (_, __) => Positioned(
                bottom: 52,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: _dotFade.value,
                  child: Column(
                    children: [
                      const _PulseDot(),
                      const SizedBox(height: 12),
                      Text(
                        'v1.0.0',
                        style: AppText.ui(11, color: AppColors.text3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single pulsing dot loader
class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final Animation<double> _s = Tween(
    begin: 0.6,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _s,
      builder: (_, __) => Transform.scale(
        scale: _s.value,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.gold.withValues(alpha: 0.7 * _s.value),
          ),
        ),
      ),
    );
  }
}

class _SplashBg extends StatelessWidget {
  const _SplashBg();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: _SplashBgPainter(),
    );
  }
}

class _SplashBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Faint center glow
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.gold.withValues(alpha: 0.06),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width / 2, size.height / 2),
              radius: size.width * 0.55,
            ),
          );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glow);

    // Corner accent lines
    final linePaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.0;

    const cornerLen = 28.0;
    const margin = 28.0;
    canvas.drawLine(
      const Offset(margin, margin),
      const Offset(margin + cornerLen, margin),
      linePaint,
    );
    canvas.drawLine(
      const Offset(margin, margin),
      const Offset(margin, margin + cornerLen),
      linePaint,
    );

    canvas.drawLine(
      Offset(size.width - margin, size.height - margin),
      Offset(size.width - margin - cornerLen, size.height - margin),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width - margin, size.height - margin),
      Offset(size.width - margin, size.height - margin - cornerLen),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
