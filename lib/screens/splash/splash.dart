import 'package:flutter/material.dart';
import 'package:runhutch/screens/home/home.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _splashDuration = Duration(seconds: 3);

  late final AnimationController _runController;
  late final AnimationController _progressController;
  late final Animation<double> _bounceAnimation;
  late final Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    _runController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..repeat();

    _progressController = AnimationController(
      vsync: this,
      duration: _splashDuration,
    );

    _bounceAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _runController, curve: Curves.easeInOut),
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    );

    _progressController.forward().whenComplete(_navigateToHome);
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  void dispose() {
    _runController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF8A50),
              Color(0xFFFF6B35),
              Color(0xFFE85D04),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, -8 * _bounceAnimation.value),
                      child: child,
                    );
                  },
                  child: AnimatedBuilder(
                    animation: _runController,
                    builder: (context, _) {
                      return CustomPaint(
                        size: const Size(140, 100),
                        painter: _RunningRabbitPainter(
                          phase: _runController.value,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'RunHutch',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Getting ready to hop...',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                ),
                const Spacer(flex: 3),
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, _) {
                    final progress = _progressAnimation.value;
                    return Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 10,
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.25),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${(progress * 100).round()}%',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RunningRabbitPainter extends CustomPainter {
  _RunningRabbitPainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final groundY = size.height * 0.82;

    final bodyPaint = Paint()..color = const Color(0xFFFFF8F0);
    final detailPaint = Paint()
      ..color = const Color(0xFFFFB347)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final eyePaint = Paint()..color = const Color(0xFF4A2C2A);

    final legSwing = (phase < 0.5 ? phase * 2 : (1 - phase) * 2) * 14;
    final backLegSwing = -legSwing;

    canvas.save();
    canvas.translate(centerX, groundY);

    // Back leg
    _drawLeg(canvas, Offset(-18, -8), backLegSwing, bodyPaint);

    // Body
    final bodyRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-35, -38, 70, 42),
      const Radius.circular(20),
    );
    canvas.drawRRect(bodyRect, bodyPaint);
    canvas.drawRRect(bodyRect, detailPaint);

    // Head
    canvas.drawCircle(const Offset(28, -48), 22, bodyPaint);
    canvas.drawCircle(const Offset(28, -48), 22, detailPaint);

    // Ears
    _drawEar(canvas, const Offset(18, -68), -0.25, bodyPaint, detailPaint);
    _drawEar(canvas, const Offset(38, -68), 0.2, bodyPaint, detailPaint);

    // Eyes
    canvas.drawCircle(const Offset(22, -50), 3.5, eyePaint);
    canvas.drawCircle(const Offset(36, -50), 3.5, eyePaint);

    // Nose
    final nosePaint = Paint()..color = const Color(0xFFFF8A65);
    canvas.drawCircle(const Offset(44, -44), 4, nosePaint);

    // Front leg
    _drawLeg(canvas, Offset(20, -8), legSwing, bodyPaint);

    // Tail
    canvas.drawCircle(const Offset(-38, -28), 10, bodyPaint);
    canvas.drawCircle(const Offset(-38, -28), 10, detailPaint);

    canvas.restore();

    // Ground dust puffs
    final dustPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35 * (1 - phase).abs())
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX - 50, groundY + 4), 4, dustPaint);
    canvas.drawCircle(Offset(centerX + 45, groundY + 6), 3, dustPaint);
  }

  void _drawLeg(
    Canvas canvas,
    Offset origin,
    double swing,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(swing * 0.04);
    final legRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-6, 0, 12, 22),
      const Radius.circular(6),
    );
    canvas.drawRRect(legRect, paint);
    canvas.restore();
  }

  void _drawEar(
    Canvas canvas,
    Offset origin,
    double tilt,
    Paint fill,
    Paint stroke,
  ) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(tilt);
    final earPath = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(6, -28, 0, -42)
      ..quadraticBezierTo(-6, -28, 0, 0)
      ..close();
    canvas.drawPath(earPath, fill);
    canvas.drawPath(earPath, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RunningRabbitPainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}
