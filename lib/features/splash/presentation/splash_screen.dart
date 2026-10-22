import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';

/// Cold-start brand moment: pin, ripples, wordmark and tagline settle in,
/// then the app replaces this route with Explore so it never sits on the
/// back stack. Nothing here waits on Mapbox, GPS, SQLite or the network.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const tagline = 'Ang tamang pwesto, simula ng negosyo.';
  static const footer = 'Location intelligence for small businesses';

  /// Full sequence, including a short settle before leaving.
  static const duration = Duration(milliseconds: 1900);

  /// With reduced motion the static composition is held briefly instead.
  static const reducedMotionDuration = Duration(milliseconds: 700);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;
  bool _reducedMotion = false;
  bool _left = false;

  late final Animation<double> _pinFade = _interval(0.0, 0.32, Curves.easeOut);
  late final Animation<double> _pinScale = Tween<double>(
    begin: 0.82,
    end: 1,
  ).animate(_interval(0.0, 0.38, Curves.easeOutCubic));
  late final Animation<double> _wordFade = _interval(
    0.28,
    0.56,
    Curves.easeOut,
  );
  late final Animation<double> _wordRise = _interval(
    0.28,
    0.62,
    Curves.easeOutCubic,
  );
  late final Animation<double> _taglineFade = _interval(
    0.44,
    0.70,
    Curves.easeOut,
  );
  late final Animation<double> _footerFade = _interval(
    0.56,
    0.82,
    Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: SplashScreen.duration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) _leave();
          });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      // Show the settled composition immediately, hold, then leave.
      _controller.duration = SplashScreen.reducedMotionDuration;
      _reducedMotion = true;
    }
    _controller.forward();
  }

  Animation<double> _interval(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, end, curve: curve),
      );

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    context.go(AppRoutes.explore);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _v(Animation<double> a) => _reducedMotion ? 1 : a.value;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _SplashColors.bottom,
      ),
      child: Scaffold(
        backgroundColor: BrandColors.emerald900,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _SplashColors.top,
                BrandColors.emerald900,
                _SplashColors.bottom,
              ],
              stops: [0, 0.55, 1],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final shortest = math.min(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              final logo = (shortest * 0.24).clamp(72.0, 104.0);
              final wordSize = (shortest * 0.105).clamp(30.0, 44.0);
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Stack(
                  fit: StackFit.expand,
                  children: [
                    const CustomPaint(painter: _GridPainter()),
                    SafeArea(
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xxl,
                                ),
                                physics: const NeverScrollableScrollPhysics(),
                                child: _composition(logo, wordSize),
                              ),
                            ),
                          ),
                          Opacity(
                            opacity: _v(_footerFade),
                            child: const _Footer(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _composition(double logo, double wordSize) {
    final theme = Theme.of(context);
    final ripple = _reducedMotion ? 0.0 : _controller.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: logo * 2.4,
          height: logo * 2.4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(logo * 2.4),
                painter: _RipplePainter(progress: ripple, logo: logo),
              ),
              Opacity(
                opacity: _v(_pinFade),
                child: Transform.scale(
                  scale: _reducedMotion ? 1 : _pinScale.value,
                  child: _PinTile(size: logo),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Opacity(
          opacity: _v(_wordFade),
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - _v(_wordRise))),
            child: Text(
              'PWESTADO',
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontSize: wordSize,
                fontWeight: FontWeight.w900,
                letterSpacing: wordSize * 0.14,
                height: 1.1,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Opacity(
          opacity: _v(_taglineFade),
          child: Text(
            SplashScreen.tagline,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: BrandColors.mintSoft.withValues(alpha: 0.86),
              fontStyle: FontStyle.italic,
              height: 1.4,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

abstract final class _SplashColors {
  static const top = Color(0xFF0F4A38);
  static const bottom = Color(0xFF082E23);
}

/// Larger take on the BrandHeader logo: emerald tile, mint pin, base line.
class _PinTile extends StatelessWidget {
  const _PinTile({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BrandColors.emerald500, BrandColors.emerald800],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: BrandColors.mint.withValues(alpha: 0.28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55041E16),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.place_rounded,
            color: BrandColors.mint,
            size: size * 0.6,
            semanticLabel: 'PWESTADO logo',
          ),
          Positioned(
            bottom: size * 0.19,
            child: Container(
              width: size * 0.3,
              height: size * 0.045,
              decoration: BoxDecoration(
                color: BrandColors.mint.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two mint rings that expand from behind the pin and fade out.
class _RipplePainter extends CustomPainter {
  const _RipplePainter({required this.progress, required this.logo});

  final double progress;
  final double logo;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (final start in const [0.12, 0.34]) {
      final t = ((progress - start) / 0.55).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      final eased = Curves.easeOutCubic.transform(t);
      final radius = logo * (0.5 + 0.7 * eased);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = BrandColors.mint.withValues(alpha: 0.45 * (1 - t));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.progress != progress || old.logo != logo;
}

/// Faint map-like grid that hints at location without competing for focus.
class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BrandColors.mint.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const step = 44.0;
    for (var x = step / 2; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = step / 2; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 2,
            decoration: BoxDecoration(
              color: BrandColors.mint.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            SplashScreen.footer.toUpperCase(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: BrandColors.mint.withValues(alpha: 0.7),
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
