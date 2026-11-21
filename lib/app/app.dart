import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/core.dart';
import '../data/data.dart';
import '../features/auth/login_screen.dart';
import '../features/shell/home_shell.dart';
import '../features/splash/splash_screen.dart';

class AltairApp extends ConsumerWidget {
  const AltairApp({super.key, required this.backendReady, this.startupError});

  final bool backendReady;
  final Object? startupError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildAltairTheme(AltairPalette.light),
      darkTheme: buildAltairTheme(AltairPalette.dark),
      themeMode: mode,
      themeAnimationDuration: const Duration(milliseconds: 350),
      builder: (context, child) {
        final p = context.palette;
        final overlay =
            (p.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                .copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: p.bgDeep,
                  systemNavigationBarIconBrightness: p.isDark
                      ? Brightness.light
                      : Brightness.dark,
                );
        Widget content = AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay,
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 0.9,
            maxScaleFactor: 1.3,
            child: child ?? const SizedBox.shrink(),
          ),
        );
        if (AppConfig.useEmulators) {
          content = Banner(
            message: 'DEV MODE',
            location: BannerLocation.topEnd,
            color: p.accent,
            textStyle: TextStyle(
              color: p.onAccent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
            child: content,
          );
        }
        return content;
      },
      home: backendReady
          ? const RootGate()
          : SetupRequiredScreen(error: startupError),
    );
  }
}

/// Decides what is on screen: the startup sequence, the sign-in screen
/// or the dashboards. When the startup sequence ends, the logo glides from
/// the centre of the screen to its place on the next screen.
class RootGate extends ConsumerStatefulWidget {
  const RootGate({super.key});

  @override
  ConsumerState<RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<RootGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  bool _splashDone = false;
  bool _sessionChecked = false;
  bool _onSplash = true;
  Rect? _from;
  Rect? _to;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  /// "Stay signed in" off means a fresh launch must sign in again.
  Future<void> _checkSession() async {
    try {
      final auth = ref.read(authRepositoryProvider);
      final remember = ref.read(settingsProvider).rememberMe;
      final user = await auth.authState().first.timeout(
        const Duration(seconds: 5),
      );
      if (user != null && !remember) await auth.signOut();
    } catch (_) {}
    if (mounted) setState(() => _sessionChecked = true);
  }

  void _onSplashFinished() {
    // Landing places stay empty until the logo has arrived.
    if (!Motion.reduced) LogoFlight.docked.value = false;
    if (mounted) setState(() => _splashDone = true);
  }

  /// Runs one frame after the next screen was built, when both the logo on
  /// the startup screen and its landing place can be measured.
  void _startFlight() {
    if (!mounted) return;
    final from = LogoFlight.rectOf(LogoFlight.splashKey);
    final to =
        LogoFlight.rectOf(LogoFlight.loginSlot) ??
        LogoFlight.rectOf(LogoFlight.homeSlot);
    if (Motion.reduced || from == null || to == null) {
      LogoFlight.docked.value = true;
      return;
    }
    setState(() {
      _from = from;
      _to = to;
    });
    LogoFlight.flying.value = true;
    _flight.forward(from: 0).whenComplete(() {
      LogoFlight.docked.value = true;
      LogoFlight.flying.value = false;
      if (mounted) {
        setState(() {
          _from = null;
          _to = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final showSplash = !_splashDone || !_sessionChecked || auth.isLoading;
    if (_onSplash && !showSplash) {
      _onSplash = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startFlight());
    }

    final Widget page;
    if (showSplash) {
      page = SplashScreen(
        key: const ValueKey('splash'),
        onFinished: _onSplashFinished,
      );
    } else if (auth.value == null) {
      page = const LoginScreen(key: ValueKey('login'));
    } else {
      page = const HomeShell(key: ValueKey('home'));
    }

    final from = _from;
    final to = _to;
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 700),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: page,
        ),
        if (from != null && to != null)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _flight,
              builder: (context, _) {
                final rect = Rect.lerp(
                  from,
                  to,
                  Motion.expo.transform(_flight.value),
                )!;
                return Stack(
                  children: [
                    Positioned.fromRect(
                      rect: rect,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: AltairMark(width: from.width),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Shown instead of crashing when the app has not been linked to a
/// Firebase project yet.
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key, this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: GlassSurface(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 34,
                        color: p.accentText,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'BACKEND NOT CONNECTED',
                        style: T.display(context).copyWith(fontSize: 19),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        error == null
                            ? 'This build is not linked to a Firebase project yet.\n\n'
                                  'Run "flutterfire configure" in the project folder '
                                  '(BUILD_GUIDE.md, Part 3), then build the app again.\n\n'
                                  'To try the app before that, start the Firebase '
                                  'emulators and run it with\n'
                                  '--dart-define=ALTAIR_EMULATORS=true'
                            : 'Firebase could not start on this device.\n\n$error',
                        style: T.body(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
