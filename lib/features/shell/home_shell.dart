import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../admin/admin_panel.dart';
import '../auth/join_request.dart';
import '../history/history_dashboard.dart';
import '../hub/quick_tools.dart';
import '../hub/team_hub_screen.dart';
import '../members/members_dashboard.dart';
import '../notes/notes_dashboard.dart';
import '../profile/change_password_sheet.dart';
import '../profile/profile_screen.dart';
import '../splash/splash_screen.dart';
import '../tasks/tasks_dashboard.dart';
import 'dashboard_scaffold.dart';

const _icons = <IconData>[
  Icons.precision_manufacturing_outlined,
  Icons.history_rounded,
  Icons.campaign_outlined,
  Icons.verified_user_outlined,
  Icons.tips_and_updates_outlined,
  Icons.military_tech_outlined,
  Icons.engineering_outlined,
  Icons.school_outlined,
];

/// Share of the portal animation after which the screen is fully covered
/// and the dashboard underneath is swapped.
const _coverAt = 0.58;

/// The signed-in app: eight dashboards you can swipe between, a floating
/// glass top bar and a glass navigation pill (a side list on tablets).
/// Tapping a destination "travels" there through an expanding portal.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _pages = PageController();
  late final AnimationController _portal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..addListener(_onPortalTick);

  int _index = 0;
  int? _portalTarget;
  int _portalLabel = 0;
  Offset _portalOrigin = Offset.zero;
  bool _passwordPrompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _portal.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncClock();
  }

  void _syncClock() {
    final uid = ref.read(uidProvider);
    if (uid != null) ref.read(serverClockProvider).sync(uid);
  }

  void _startSession() {
    if (!mounted) return;
    ref.read(dashboardNavProvider.notifier).show(0);
    _syncClock();
    final user = ref.read(currentUserProvider).value;
    if (user != null) _onUserChanged(user);
  }

  /// Reacts to the administrator changing this account while it is open.
  Future<void> _onUserChanged(AppUser user) async {
    if (user.disabled) {
      if (mounted) {
        showToast(
          context,
          'This account has been disabled by the administrator.',
          error: true,
        );
      }
      await ref.read(authRepositoryProvider).signOut();
      return;
    }
    if (user.mustChangePassword && !_passwordPrompted) {
      _passwordPrompted = true;
      // Wait until the intro has settled before asking.
      await Future<void>.delayed(const Duration(milliseconds: 1900));
      if (mounted) await showChangePassword(context, firstTime: true);
    }
  }

  // Live alerts: what teammates just did, shown while the app is open.

  void _announce(LiveAlert alert) {
    if (!mounted || !ref.read(settingsProvider).alertOn(alert.topic)) return;
    showToast(
      context,
      alert.message,
      icon: Icons.notifications_active_outlined,
    );
  }

  Future<void> _announceCompleted(String taskId, String myId) async {
    try {
      final record = await ref.read(taskRepositoryProvider).finished(taskId);
      if (record == null) return;
      final alert = LiveAlerts.completed(record, myId);
      if (alert != null) _announce(alert);
    } catch (_) {
      // Offline: the alert is skipped, the data itself is unaffected.
    }
  }

  void _onTasks(
    AsyncValue<List<RoverTask>>? previous,
    AsyncValue<List<RoverTask>> next,
  ) {
    final before = previous?.value;
    final after = next.value;
    final myId = ref.read(uidProvider);
    if (before == null || after == null || myId == null) return;
    final alerts = LiveAlerts.tasks(
      before,
      after,
      myId,
      gone: (taskId) => _announceCompleted(taskId, myId),
    );
    alerts.forEach(_announce);
  }

  void _onNotes(
    AsyncValue<List<Note>>? previous,
    AsyncValue<List<Note>> next,
  ) {
    final before = previous?.value;
    final after = next.value;
    final myId = ref.read(uidProvider);
    if (before == null || after == null || myId == null) return;
    LiveAlerts.notes(before, after, myId).forEach(_announce);
  }

  // Moving between dashboards.

  double get _page {
    if (_pages.hasClients && _pages.position.haveDimensions) {
      return _pages.page ?? _index.toDouble();
    }
    return _index.toDouble();
  }

  void _onPageChanged(int index) {
    if (index == _index) return;
    Haptics.select();
    setState(() => _index = index);
    ref.read(dashboardNavProvider.notifier).show(index);
  }

  /// Opens a portal at [origin], swaps the dashboard while the screen is
  /// covered, then lets the portal fade away.
  void _travel(int index, Offset origin) {
    if (index == _index || _portal.isAnimating || !_pages.hasClients) return;
    if (Motion.reduced) {
      _pages.jumpToPage(index);
      return;
    }
    _portalTarget = index;
    _portalLabel = index;
    _portalOrigin = origin;
    _portal.forward(from: 0);
  }

  void _onPortalTick() {
    final target = _portalTarget;
    if (target == null || _portal.value < _coverAt) return;
    _portalTarget = null;
    if (_pages.hasClients) _pages.jumpToPage(target);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppUser?>>(currentUserProvider, (previous, next) {
      final user = next.value;
      if (user != null) _onUserChanged(user);
    });
    ref.listen<AsyncValue<List<RoverTask>>>(activeTasksProvider, _onTasks);
    ref.listen<AsyncValue<List<Note>>>(latestNotesProvider, _onNotes);

    final userState = ref.watch(currentUserProvider);
    final user = userState.value;

    final muted = ref.watch(settingsProvider.select((s) => s.mutedAlerts));
    if (user != null) {
      Push.sync({
        for (final t in alertTopics)
          if (!muted.contains(t.key) && (user.role.isLead || !t.leadsOnly))
            t.key,
      });
    }

    Widget? notice;
    if (user == null) {
      // Signed in without an account: someone asking to join.
      notice = userState.isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : userState.hasError
          ? _NoProfile(message: friendlyError(userState.error!))
          : const JoinGate();
    }
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AmbientBackground(
        child: Stack(
          children: [
            Positioned.fill(child: _layout(context, user, notice)),
            Positioned.fill(child: _portalLayer(context)),
          ],
        ),
      ),
    );
  }

  Size? _lastSize;

  /// After the screen turns, draw a few more frames once it has settled.
  /// Otherwise the glass dial can keep the blank (white) backdrop it caught
  /// mid-turn until something else on screen moves.
  void _watchSize(Size size) {
    final before = _lastSize;
    _lastSize = size;
    if (before == null || before == size) return;
    for (final ms in const [150, 400, 800]) {
      Future<void>.delayed(Duration(milliseconds: ms), () {
        if (mounted) setState(() {});
      });
    }
  }

  Widget _layout(BuildContext context, AppUser? user, Widget? notice) {
    final safe = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _watchSize(constraints.biggest);
        final ready = user != null;
        final Widget body = ready
            ? PageView(
                controller: _pages,
                onPageChanged: _onPageChanged,
                children: const [
                  _KeepAlive(child: TasksDashboard()),
                  _KeepAlive(child: HistoryDashboard()),
                  _KeepAlive(child: NotesDashboard()),
                  _KeepAlive(
                    child: MembersDashboard(group: MemberGroup.moderators),
                  ),
                  _KeepAlive(
                    child: MembersDashboard(group: MemberGroup.advisors),
                  ),
                  _KeepAlive(
                    child: MembersDashboard(group: MemberGroup.teamLeads),
                  ),
                  _KeepAlive(
                    child: MembersDashboard(group: MemberGroup.seniorMembers),
                  ),
                  _KeepAlive(
                    child: MembersDashboard(group: MemberGroup.juniorMembers),
                  ),
                ],
              )
            : notice ?? const SizedBox.shrink();
        final content = ShellInsets(
          top: safe.top + 8 + 60,
          bottom: safe.bottom + 6 + _BottomNav.radius + 8,
          travel: _travel,
          child: Stack(
            children: [
              Positioned.fill(child: body),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, safe.top + 8, 12, 0),
                  child: _TopBar(user: user),
                ),
              ),
              if (ready)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _Rise(
                    child: _BottomNav(
                      controller: _pages,
                      page: () => _page,
                      onTap: _travel,
                      lift: safe.bottom + 6,
                    ),
                  ),
                ),
              if (ready)
                Positioned.fill(
                  child: QuickTools(
                    dialTop: (x) =>
                        safe.bottom +
                        6 +
                        _BottomNav.heightAt(constraints.maxWidth, x),
                  ),
                ),
            ],
          ),
        );
        return content;
      },
    );
  }

  /// The portal: a rounded window that grows from the tapped control until
  /// it covers the screen, then fades to reveal the new dashboard.
  Widget _portalLayer(BuildContext context) {
    final p = context.palette;
    return AnimatedBuilder(
      animation: _portal,
      builder: (context, _) {
        final t = _portal.value;
        if (t <= 0 || t >= 1) return const SizedBox.shrink();
        final grow = Motion.inOutCubic((t / _coverAt).clamp(0.0, 1.0));
        final fade = t <= _coverAt
            ? 1.0
            : 1 -
                  Curves.easeOut.transform(
                    ((t - _coverAt) / (1 - _coverAt)).clamp(0.0, 1.0),
                  );
        final screen = Offset.zero & MediaQuery.sizeOf(context);
        final window = Rect.lerp(
          Rect.fromCenter(center: _portalOrigin, width: 72, height: 48),
          screen,
          grow,
        )!;
        return AbsorbPointer(
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: window,
                child: Opacity(
                  opacity: fade.clamp(0.0, 1.0).toDouble(),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.bgDeep,
                      borderRadius: BorderRadius.circular(26 * (1 - grow)),
                      border: Border.all(
                        color: p.accent.withValues(alpha: 0.9 * (1 - grow)),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Center(
                        child: Opacity(
                          opacity: (grow * 1.5 - 0.5).clamp(0.0, 1.0).toDouble(),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              dashboardNames[_portalLabel].toUpperCase(),
                              style: T.giant(context, 72),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Slides the navigation up from below the screen when the shell appears.
class _Rise extends StatelessWidget {
  const _Rise({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Motion.off(context)
        ? Duration.zero
        : const Duration(milliseconds: 1000),
    curve: Motion.expo,
    builder: (context, v, child) =>
        Transform.translate(offset: Offset(0, 200 * (1 - v)), child: child),
    child: child,
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final me = user;
    return GlassSurface(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            LogoSlot(slot: LogoFlight.homeSlot, width: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'PROJECT ALTAIR',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.title(
                  context,
                ).copyWith(fontSize: 14, letterSpacing: 2.6),
              ),
            ),
            if (me != null) ...[
              RoundIconButton(
                icon: Icons.apps_rounded,
                tooltip: 'Team hub',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const TeamHubScreen()),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (me != null && me.role.isAdmin) ...[
              const _AdminButton(),
              const SizedBox(width: 8),
            ],
            if (me != null)
              PressScale(
                scale: 0.92,
                semanticLabel: 'Profile and settings',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfileScreen(),
                  ),
                ),
                child: Avatar(
                  name: me.fullName,
                  url: me.photoUrl,
                  size: 42,
                  ring: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Phone navigation: a wide glass half-oval dial. The pages sit around its
/// rim and the one in view turns to the top, under the orange marker.
/// Swipe across the dial (or the page itself) to turn it, or tap a page.
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.controller,
    required this.page,
    required this.onTap,
    required this.lift,
  });

  final PageController controller;
  final double Function() page;
  final void Function(int index, Offset origin) onTap;

  /// Space under the dial (the phone's gesture bar).
  final double lift;

  /// Height of the dial. Its width follows the screen, so it is a wide,
  /// flat half-oval rather than a half-circle.
  static const radius = 112.0;

  /// Widest the dial gets, on big phones.
  static const _maxHalfWidth = 230.0;

  /// How far in from the dial's edge the page icons travel.
  static const _inset = 32.0;

  /// Angle between neighbouring pages on the rim (about 39 degrees).
  static const step = 0.68;

  static double _halfWidth(double screenWidth) =>
      math.min(screenWidth / 2 - 8, _maxHalfWidth);

  /// How tall the dial is at [x] on a screen [screenWidth] wide (not
  /// counting the gesture-bar space under it).
  static double heightAt(double screenWidth, double x) {
    final half = _halfWidth(screenWidth);
    final dx = (x - screenWidth / 2) / half;
    return dx.abs() >= 1 ? 0.0 : radius * math.sqrt(1 - dx * dx);
  }

  void _turn(DragUpdateDetails d, double perPage) {
    if (!controller.hasClients) return;
    final pos = controller.position;
    final pixels = pos.pixels - d.delta.dx * pos.viewportDimension / perPage;
    pos.jumpTo(
      pixels.clamp(pos.minScrollExtent, pos.maxScrollExtent).toDouble(),
    );
  }

  void _settle(BuildContext context, DragEndDetails d, double perPage) {
    if (!controller.hasClients) return;
    final fling = -(d.primaryVelocity ?? 0) / perPage * 0.08;
    final target = math.max(
      0,
      math.min(dashboardNames.length - 1, (page() + fling).round()),
    );
    if (Motion.off(context)) {
      controller.jumpToPage(target);
    } else {
      controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final half = _halfWidth(constraints.maxWidth);
        // The oval the icons travel on: wide, but no taller than before.
        final rim = Size(half - _inset, radius - _inset);
        // Finger travel near the top that turns the dial by one page.
        final perPage = rim.width * step;
        return Center(
          child: GestureDetector(
            onHorizontalDragUpdate: (d) => _turn(d, perPage),
            onHorizontalDragEnd: (d) => _settle(context, d, perPage),
            child: GlassSurface(
              borderRadius: BorderRadius.vertical(
                top: Radius.elliptical(half, radius),
              ),
              child: SizedBox(
                width: half * 2,
                height: radius + lift,
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    final position = page();
                    final near = math.max(
                      0,
                      math.min(dashboardNames.length - 1, position.round()),
                    );
                    final settled = (1 - 2 * (position - near).abs())
                        .clamp(0.0, 1.0)
                        .toDouble();
                    return Stack(
                      children: [
                        Positioned(
                          left: half - 25,
                          top: radius - rim.height - 25,
                          width: 50,
                          height: 50,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.accent,
                              boxShadow: [
                                BoxShadow(
                                  color: p.accent.withValues(alpha: 0.34),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                        ),
                        for (var i = 0; i < dashboardNames.length; i++)
                          if ((i - position).abs() < 2.6)
                            _RimItem(
                              index: i,
                              offset: i - position,
                              centre: Offset(half, radius),
                              rim: rim,
                              onTap: onTap,
                            ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: radius - rim.height + 36,
                          child: Opacity(
                            opacity: settled,
                            child: Text(
                              dashboardNames[near].toUpperCase(),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 1.4,
                                color: p.text,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: radius - rim.height + 58,
                          child: _Dots(position: position),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One page icon on the dial's rim, [offset] pages away from the top.
class _RimItem extends StatelessWidget {
  const _RimItem({
    required this.index,
    required this.offset,
    required this.centre,
    required this.rim,
    required this.onTap,
  });

  final int index;
  final double offset;

  /// Middle of the dial's flat bottom edge.
  final Offset centre;

  /// Width and height radius of the oval the icons travel on.
  final Size rim;
  final void Function(int index, Offset origin) onTap;

  static const _size = 46.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final angle = offset * _BottomNav.step;
    final x = centre.dx + rim.width * math.sin(angle);
    final y = centre.dy - rim.height * math.cos(angle);
    final covered = (1 - offset.abs()).clamp(0.0, 1.0).toDouble();
    final color = Color.lerp(p.textFaint, p.onAccent, covered) ?? p.textFaint;
    return Positioned(
      left: x - _size / 2,
      top: y - _size / 2,
      width: _size,
      height: _size,
      child: Opacity(
        opacity: (2.6 - offset.abs()).clamp(0.0, 1.0).toDouble(),
        child: PressScale(
          onTap: () => onTap(index, centerOf(context)),
          haptic: false,
          scale: 0.9,
          semanticLabel: dashboardNames[index],
          child: Center(
            child: Transform.scale(
              scale: 1 + 0.15 * covered,
              child: Icon(_icons[index], size: 22, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the page in view sits among all the pages.
class _Dots extends StatelessWidget {
  const _Dots({required this.position});

  final double position;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < dashboardNames.length; i++)
        _dot(context, (1 - (i - position).abs()).clamp(0.0, 1.0).toDouble()),
    ],
  );

  Widget _dot(BuildContext context, double t) {
    final p = context.palette;
    return Container(
      width: 5 + 7 * t,
      height: 5,
      margin: const EdgeInsets.symmetric(horizontal: 2.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: Color.lerp(p.textFaint.withValues(alpha: 0.45), p.accent, t),
      ),
    );
  }
}

/// Opens Admin control. An orange dot shows while join requests wait.
class _AdminButton extends ConsumerWidget {
  const _AdminButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiting = (ref.watch(pendingJoinRequestsProvider).value ?? const [])
        .isNotEmpty;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        RoundIconButton(
          icon: Icons.admin_panel_settings_outlined,
          tooltip: waiting
              ? 'Administrator control panel - join requests waiting'
              : 'Administrator control panel',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AdminPanel()),
          ),
        ),
        if (waiting)
          Positioned(
            right: 1,
            top: 1,
            child: IgnorePointer(
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.palette.accent,
                  border: Border.all(color: context.palette.bg, width: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NoProfile extends ConsumerWidget {
  const _NoProfile({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Profile unavailable',
              message: message,
            ),
            GhostButton(
              label: 'Sign out',
              icon: Icons.logout_rounded,
              expand: false,
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
            ),
          ],
        ),
      ),
    ),
  );
}
