import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _ballController;
  late AnimationController _fadeController;
  late AnimationController _glowController;
  late AnimationController _textController;

  late Animation<double> _ballRotation;
  late Animation<double> _ballScale;
  late Animation<double> _ballBounce;
  late Animation<double> _fadeIn;
  late Animation<double> _glowPulse;
  late Animation<double> _textSlide;
  late Animation<double> _textFade;
  late Animation<double> _taglineSlide;
  late Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();

    _ballController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _ballRotation = Tween<double>(begin: -0.3, end: 0.0).animate(
      CurvedAnimation(parent: _ballController, curve: Curves.elasticOut),
    );

    _ballScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ballController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _ballBounce = Tween<double>(begin: -60.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ballController,
        curve: const Interval(0.0, 0.6, curve: Curves.bounceOut),
      ),
    );

    _fadeIn = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _glowPulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _textSlide = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: const Interval(0.0, 0.7)),
    );

    _taglineSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: const Interval(0.3, 1.0)),
    );

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _ballController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 2000));
    _navigateToAuth();
  }

  void _navigateToAuth() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AuthGate(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _ballController.dispose();
    _fadeController.dispose();
    _glowController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        children: [
          // Background court lines
          const _CourtLinesBackground(),

          // Radial glow background
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Center(
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(
                          0xFFFF6B1A,
                        ).withOpacity(0.15 * _glowPulse.value),
                        const Color(
                          0xFFFF6B1A,
                        ).withOpacity(0.05 * _glowPulse.value),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Basketball icon
                AnimatedBuilder(
                  animation: _ballController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _ballBounce.value),
                      child: Transform.rotate(
                        angle: _ballRotation.value,
                        child: Transform.scale(
                          scale: _ballScale.value,
                          child: _buildBasketballIcon(),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // App name
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _textSlide.value),
                      child: Opacity(opacity: _textFade.value, child: child),
                    );
                  },
                  child: Text(
                    'HOOPLYTICS',
                    style: GoogleFonts.outfit(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: const Color(0xFFFF6B1A).withOpacity(0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Tagline
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _taglineSlide.value),
                      child: Opacity(opacity: _taglineFade.value, child: child),
                    );
                  },
                  child: Text(
                    'Make every shot count.',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.5,
                      color: Colors.white.withOpacity(0.45),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom loading indicator
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeIn,
              child: Column(
                children: [
                  const _LoadingDots(),
                  const SizedBox(height: 16),
                  Text(
                    'Ładowanie statystyk...',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.3),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasketballIcon() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFFFF6B1A,
                ).withOpacity(0.6 * _glowPulse.value),
                blurRadius: 40,
                spreadRadius: 10,
              ),
              BoxShadow(
                color: const Color(0xFFFF6B1A).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: const _BasketballPainter(),
    );
  }
}

class _BasketballPainter extends StatelessWidget {
  const _BasketballPainter();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(110, 110), painter: _BallPainter());
  }
}

class _BallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Base ball gradient
    final ballPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: const [
          Color(0xFFFF8C42),
          Color(0xFFFF6B1A),
          Color(0xFFD94F0A),
          Color(0xFFAA3500),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, ballPaint);

    // Lines
    final linePaint = Paint()
      ..color = const Color(0xFF1A0A00).withOpacity(0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Vertical seam
    final vertPath = Path();
    vertPath.moveTo(size.width / 2, 4);
    vertPath.cubicTo(
      size.width / 2 + 18,
      size.height * 0.3,
      size.width / 2 + 18,
      size.height * 0.7,
      size.width / 2,
      size.height - 4,
    );
    canvas.drawPath(vertPath, linePaint);

    final vertPath2 = Path();
    vertPath2.moveTo(size.width / 2, 4);
    vertPath2.cubicTo(
      size.width / 2 - 18,
      size.height * 0.3,
      size.width / 2 - 18,
      size.height * 0.7,
      size.width / 2,
      size.height - 4,
    );
    canvas.drawPath(vertPath2, linePaint);

    // Horizontal seam
    canvas.drawLine(
      Offset(6, size.height / 2),
      Offset(size.width - 6, size.height / 2),
      linePaint,
    );

    // Highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(
      Offset(center.dx - radius * 0.3, center.dy - radius * 0.3),
      radius * 0.3,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CourtLinesBackground extends StatelessWidget {
  const _CourtLinesBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: _CourtLinesPainter(),
    );
  }
}

class _CourtLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Three-point arc (bottom portion)
    final arcRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height + 20),
      width: size.width * 0.85,
      height: size.width * 0.85,
    );
    canvas.drawArc(arcRect, math.pi * 1.1, math.pi * 0.8, false, paint);

    // Paint (key) box
    final keyW = size.width * 0.28;
    final keyH = size.height * 0.22;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height),
        width: keyW,
        height: keyH * 2,
      ),
      paint,
    );

    // Free throw circle
    final ftCircle = Rect.fromCenter(
      center: Offset(size.width / 2, size.height - keyH),
      width: keyW * 0.7,
      height: keyW * 0.7,
    );
    canvas.drawOval(ftCircle, paint);

    // Corner lines (subtle)
    final cornerPaint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 1; i < 4; i++) {
      canvas.drawLine(
        Offset(0, size.height * i / 4),
        Offset(size.width, size.height * i / 4),
        cornerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
    _anims = _controllers
        .map(
          (c) => Tween<double>(
            begin: 0.3,
            end: 1.0,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
        )
        .toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _anims[i],
          builder: (context, _) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF6B1A).withOpacity(_anims[i].value),
              ),
            );
          },
        );
      }),
    );
  }
}
