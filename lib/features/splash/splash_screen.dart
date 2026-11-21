import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/core.dart';

const altairMarkAsset = 'assets/branding/altair_mark.png';

/// Height / width of the arm mark image (747 x 965 px source).
const _markAspect = 747 / 965;

/// The official arm mark, drawn from the logo file with its own proportions.
class AltairMark extends StatelessWidget {
  const AltairMark({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: width * _markAspect,
    child: Image.asset(
      altairMarkAsset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Project Altair',
      errorBuilder: (context, error, stack) => Icon(
        Icons.precision_manufacturing_rounded,
        size: width * 0.6,
        color: AltairPalette.logoOrange,
      ),
    ),
  );
}

/// The logo "docks": after the intro it glides from the centre of the
/// screen to its place on the next screen (top-left bar, or above the
/// sign-in form). These keys tell the app where those places are.
abstract final class LogoFlight {
  static final splashKey = GlobalKey(debugLabel: 'splash logo');
  static final loginSlot = GlobalKey(debugLabel: 'login logo');
  static final homeSlot = GlobalKey(debugLabel: 'home logo');

  /// False from the end of the intro until the logo has landed.
  static final docked = ValueNotifier<bool>(true);

  /// True while the gliding copy is on screen.
  static final flying = ValueNotifier<bool>(false);

  static Rect? rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

/// A place the logo lands in. Invisible while the logo is still gliding.
class LogoSlot extends StatelessWidget {
  const LogoSlot({super.key, required this.slot, required this.width});

  final GlobalKey slot;
  final double width;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: LogoFlight.docked,
    builder: (context, docked, child) =>
        Opacity(opacity: docked ? 1 : 0, child: child),
    child: KeyedSubtree(
      key: slot,
      child: AltairMark(width: width),
    ),
  );
}

/// Startup sequence (about 2.4 s), always in the dark brand colours:
/// the arm is revealed dead-centre, PROJECT ALTAIR settles under it, and a
/// thin 0-100 % counter runs at the bottom over an orange line. At 100 %
/// the counter blurs up and away and the logo glides to its slot.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: Motion.reduced ? 900 : 2400),
  );
  late final AnimationController _leave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  late final Animation<double> _reveal = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.0, 0.46, curve: Motion.expo),
  );
  late final Animation<double> _word = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.26, 0.66, curve: Motion.soft),
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.06, 1, curve: Curves.easeInOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (!mounted) return;
      _leave.forward();
      widget.onFinished();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _leave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const orange = AltairPalette.logoOrange;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AltairPalette.logoTeal,
      body: AnimatedBuilder(
        animation: Listenable.merge([_c, _leave]),
        builder: (context, _) {
          final reveal = _reveal.value.clamp(0.0, 1.0).toDouble();
          final word = _word.value.clamp(0.0, 1.0).toDouble();
          final out = Motion.soft.transform(_leave.value);
          final percent = (_progress.value * 100).round().clamp(0, 100);

          Widget counter = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$percent',
                    style: const TextStyle(
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.w300,
                      fontSize: 64,
                      height: 1,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      '%',
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w500,
                        fontSize: 24,
                        height: 1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: 150,
                height: 2.5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: Colors.white.withValues(alpha: 0.12)),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _progress.value.clamp(0.0, 1.0).toDouble(),
                        child: const ColoredBox(color: orange),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
          if (out > 0.01) {
            counter = ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 7 * out, sigmaY: 7 * out),
              child: counter,
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.1),
                    radius: 0.9,
                    colors: [
                      orange.withValues(alpha: 0.10 * reveal),
                      orange.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: reveal,
                      child: Transform.scale(
                        scale: 0.86 + 0.14 * reveal,
                        child: ClipRect(
                          clipper: _RevealClipper(reveal),
                          child: ValueListenableBuilder<bool>(
                            valueListenable: LogoFlight.flying,
                            builder: (context, flying, child) =>
                                Opacity(opacity: flying ? 0 : 1, child: child),
                            child: KeyedSubtree(
                              key: LogoFlight.splashKey,
                              child: const AltairMark(width: 164),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Opacity(
                      opacity: word * (1 - out),
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - word)),
                        child: Column(
                          children: [
                            Text(
                              'PROJECT',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontWeight: FontWeight.w700,
                                fontSize: 22,
                                letterSpacing: 4 + 6 * (1 - word),
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'ALTAIR',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontWeight: FontWeight.w700,
                                fontSize: 36,
                                height: 1.05,
                                letterSpacing: 5 + 8 * (1 - word),
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: safeBottom + 28 + 34 * out,
                child: Opacity(
                  opacity: (1 - out).clamp(0.0, 1.0).toDouble(),
                  child: Center(child: counter),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  _RevealClipper(this.t);

  final double t;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, size.height * (1 - t), size.width, size.height);

  @override
  bool shouldReclip(_RevealClipper old) => old.t != t;
}
