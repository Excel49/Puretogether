import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/main_scaffold.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Auto navigate to home after 2.8 seconds
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      // context.read<RobotProvider>().startMockMode(); // MATIKAN MOCK MODE
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => const MainScaffold(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _pulseCtrl.dispose();
    _spinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Background Sky & Hills Gradient ────────────────────────
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFBAE6FD), // Sky blue
                  Color(0xFFE0F2FE), // Light sky
                  Color(0xFFF0FDF4), // Soft green tint
                  Color(0xFFDCFCE7), // Fresh lawn green
                ],
                stops: [0.0, 0.45, 0.75, 1.0],
              ),
            ),
          ),

          // ── Clouds and Nature Hill Art ─────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: size.height * 0.45,
            child: CustomPaint(
              painter: _NatureBackgroundPainter(),
            ),
          ),

          // ── Floating Decorative Leaves ─────────────────────────────
          _buildFloatingLeaf(top: 80, left: 24, size: 24, rotation: -0.3),
          _buildFloatingLeaf(top: 140, right: 32, size: 28, rotation: 0.4),
          _buildFloatingLeaf(top: 240, left: 16, size: 20, rotation: 0.6),
          _buildFloatingLeaf(top: 320, right: 20, size: 22, rotation: -0.5),

          // ── Content ────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 36),

                // Brand Header with Leaf
                FadeTransition(
                  opacity: _animCtrl,
                  child: Column(
                    children: [
                      // Leaf logo + Name
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                                topRight: Radius.circular(6),
                                bottomLeft: Radius.circular(20),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.eco_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'PureTogether',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0C4A6E),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'CLEANER SPACES, BRIGHTER TOGETHER.',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0369A1),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Center Robot Illustration
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (context, child) {
                    final bounce = math.sin(_pulseCtrl.value * math.pi) * 6;
                    return Transform.translate(
                      offset: Offset(0, -bounce),
                      child: child,
                    );
                  },
                  child: const _CuteRobotIllustration(),
                ),

                const Spacer(),

                // Bottom Floating Connecting Card
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFBAE6FD), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF0369A1).withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Animated circular spinner ring
                        RotationTransition(
                          turns: _spinCtrl,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE0F2FE),
                                width: 4,
                              ),
                            ),
                            child: const CircularProgressIndicator(
                              strokeWidth: 4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF0284C7)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Loading text
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Connecting to robot...',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0C4A6E),
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Establishing connection and loading robot data...',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingLeaf({
    required double top,
    double? left,
    double? right,
    required double size,
    required double rotation,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Transform.rotate(
        angle: rotation,
        child: Icon(
          Icons.eco_rounded,
          size: size,
          color: const Color(0xFF22C55E).withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

// ── Cute Robot Illustration Component ─────────────────────────────────────────
class _CuteRobotIllustration extends StatelessWidget {
  const _CuteRobotIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Shadow underneath
          Positioned(
            bottom: 6,
            child: Container(
              width: 140,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF15803D).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),

          // Robot Treads / Left Wheel
          Positioned(
            left: 12,
            bottom: 12,
            child: _buildTreadWheel(),
          ),

          // Robot Treads / Right Wheel
          Positioned(
            right: 12,
            bottom: 12,
            child: _buildTreadWheel(),
          ),

          // Robot Body
          Positioned(
            bottom: 22,
            child: Container(
              width: 110,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 32,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child:
                        Icon(Icons.eco_rounded, color: Colors.white, size: 12),
                  ),
                ),
              ),
            ),
          ),

          // Robot Head
          Positioned(
            top: 24,
            child: Container(
              width: 126,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                // Dark visor screen
                child: Container(
                  width: 104,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Left Eye (Cyan glowing circle)
                      _buildGlowingEye(),
                      const SizedBox(width: 18),
                      // Right Eye (Cyan glowing circle)
                      _buildGlowingEye(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Antenna
          Positioned(
            top: 10,
            child: Container(
              width: 6,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF94A3B8),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Positioned(
            top: 4,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Color(0xFF0284C7),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreadWheel() {
    return Container(
      width: 28,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          4,
          (index) => Container(
            width: 16,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF64748B),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlowingEye() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFF38BDF8),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF38BDF8),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ── Custom Painter for Rolling Green Hills in Background ─────────────────────
class _NatureBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Distant hill (teal/green)
    final backHillPaint = Paint()
      ..color = const Color(0xFF86EFAC).withValues(alpha: 0.5);
    final backHillPath = Path()
      ..moveTo(0, h * 0.4)
      ..quadraticBezierTo(w * 0.35, h * 0.2, w * 0.7, h * 0.45)
      ..quadraticBezierTo(w * 0.88, h * 0.55, w, h * 0.5)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(backHillPath, backHillPaint);

    // Front hill (rich vibrant green)
    final frontHillPaint = Paint()
      ..color = const Color(0xFF4ADE80).withValues(alpha: 0.6);
    final frontHillPath = Path()
      ..moveTo(0, h * 0.65)
      ..quadraticBezierTo(w * 0.45, h * 0.4, w, h * 0.7)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(frontHillPath, frontHillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
