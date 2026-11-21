import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../shell/sub_page.dart';
import '../splash/splash_screen.dart';
import '../tasks/task_widgets.dart';
import 'change_password_sheet.dart';

const _glassPresets = <(double, String)>[
  (0.0, 'Off'),
  (0.35, 'Subtle'),
  (0.6, 'Balanced'),
  (0.9, 'Vivid'),
];

/// Profile and settings, opened from the avatar in the top bar.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _changePhoto(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final source = await showOptionsSheet<ImageSource>(
      context,
      title: 'Profile picture',
      options: const [
        Option(ImageSource.gallery, 'Choose from gallery'),
        Option(ImageSource.camera, 'Take a photo'),
      ],
    );
    if (source == null) return;
    try {
      final bytes = await PhotoRepository.pick(source);
      if (bytes == null) return;
      final photo = await ref
          .read(photoRepositoryProvider)
          .save(bytes, user.id);
      await ref.read(teamRepositoryProvider).setOwnPhoto(user.id, photo);
      if (context.mounted) showToast(context, 'Profile picture updated');
    } catch (e) {
      if (context.mounted) showToast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Log out?',
      message: 'You will need your User ID and password to sign in again.',
      confirmLabel: 'Log out',
    );
    if (!ok || !context.mounted) return;
    final auth = ref.read(authRepositoryProvider);
    Navigator.of(context).popUntil((route) => route.isFirst);
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final user = ref.watch(currentUserProvider).value;
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final mustChange = user?.mustChangePassword ?? false;

    return SubPage(
      title: 'PROFILE & SETTINGS',
      children: [
        if (user != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FrostCard(
              child: Row(
                children: [
                  PressScale(
                    scale: 0.94,
                    semanticLabel: 'Change profile picture',
                    onTap: () => _changePhoto(context, ref, user),
                    child: Stack(
                      children: [
                        Avatar(
                          name: user.fullName,
                          url: user.photoUrl,
                          size: 84,
                          ring: true,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.accent,
                              border: Border.all(color: p.surface, width: 2),
                            ),
                            child: Icon(
                              Icons.photo_camera_rounded,
                              size: 14,
                              color: p.onAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: T.title(context).copyWith(fontSize: 19),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'ID  ${user.userId}',
                          style: T.mono(
                            context,
                            size: 12.5,
                            color: p.textMuted,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Tag(
                              user.position.isEmpty
                                  ? user.role.label
                                  : user.position,
                              accent: true,
                            ),
                            if (user.subTeamName.isNotEmpty)
                              Tag(user.subTeamName, icon: Icons.hub_outlined),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        SectionCard(
          title: 'Appearance',
          children: [
            const SizedBox(height: 6),
            const FieldLabel('Theme'),
            Segmented<ThemeMode>(
              options: const [
                (ThemeMode.dark, 'Dark'),
                (ThemeMode.light, 'Light'),
                (ThemeMode.system, 'System'),
              ],
              selected: settings.themeMode,
              onChanged: controller.setThemeMode,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: FieldLabel('Liquid glass effect')),
                Text(
                  settings.glass < 0.02
                      ? 'OFF'
                      : '${(settings.glass * 100).round()}%',
                  style: T.mono(context, size: 12.5, color: p.accentText),
                ),
              ],
            ),
            const _GlassPreview(),
            Slider(
              value: settings.glass,
              onChanged: controller.setGlass,
              semanticFormatterCallback: (v) => '${(v * 100).round()} percent',
            ),
            Segmented<double>(
              options: _glassPresets,
              selected: _glassPresets
                  .map((preset) => preset.$1)
                  .firstWhere(
                    (value) => (settings.glass - value).abs() < 0.03,
                    orElse: () => -1.0,
                  ),
              onChanged: controller.setGlass,
            ),
            const SizedBox(height: 10),
            Text(
              'Controls how translucent the bars, panels and pop-ups are. '
              'Off uses solid panels, which is also the fastest on older phones.',
              style: T.small(context),
            ),
            const SizedBox(height: 6),
            SettingRow(
              icon: Icons.motion_photos_off_outlined,
              title: 'Reduce motion',
              subtitle: 'Skip the reveals and the portal transition',
              trailing: AltairSwitch(
                value: settings.reduceMotion,
                onChanged: controller.setReduceMotion,
              ),
            ),
          ],
        ),
        SectionCard(
          title: 'Account & security',
          children: [
            SettingRow(
              icon: Icons.lock_reset_rounded,
              title: 'Change password',
              subtitle: mustChange
                  ? 'Recommended: yours was set by an administrator'
                  : 'Choose a new sign-in password',
              trailing: mustChange
                  ? const Tag('Do this', accent: true)
                  : null,
              onTap: () => showChangePassword(context, firstTime: mustChange),
            ),
            SettingRow(
              icon: Icons.phonelink_lock_outlined,
              title: 'Stay signed in on this phone',
              subtitle: 'Off asks for your password at every launch',
              trailing: AltairSwitch(
                value: settings.rememberMe,
                onChanged: controller.setRememberMe,
              ),
            ),
            const SettingRow(
              icon: Icons.badge_outlined,
              title: 'Name, position and sub-team',
              subtitle: 'Managed by your administrator',
            ),
          ],
        ),
        SectionCard(
          title: 'Live alerts',
          children: [
            for (final topic in alertTopics.where(
              (t) => !t.leadsOnly || (user?.role.isLead ?? false),
            ))
              SettingRow(
                icon: Icons.notifications_none_rounded,
                title: topic.title,
                subtitle: topic.subtitle,
                trailing: AltairSwitch(
                  value: settings.alertOn(topic.key),
                  onChanged: (v) => controller.setAlert(topic.key, v),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
              child: Text(
                'While the app is open, alerts appear as a banner. On '
                'Android they also arrive as notifications when it is closed.',
                style: T.small(context),
              ),
            ),
          ],
        ),
        SectionCard(
          title: 'General',
          children: [
            SettingRow(
              icon: Icons.vibration_rounded,
              title: 'Haptic feedback',
              subtitle: 'A light tap on buttons and tab changes',
              trailing: AltairSwitch(
                value: settings.haptics,
                onChanged: controller.setHaptics,
              ),
            ),
          ],
        ),
        SectionCard(
          title: 'Project Altair',
          children: [
            SettingRow(
              icon: Icons.info_outline_rounded,
              title: 'About Project Altair',
              onTap: () => showAltairSheet<void>(
                context,
                builder: (_) => const _AboutSheet(),
              ),
            ),
            SettingRow(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy policy',
              onTap: () => showAltairSheet<void>(
                context,
                builder: (_) => const _PrivacySheet(),
              ),
            ),
          ],
        ),
        GhostButton(
          label: 'Log out',
          icon: Icons.logout_rounded,
          danger: true,
          onPressed: () => _logout(context, ref),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'Version ${AppConfig.version}',
            style: T.small(context),
          ),
        ),
      ],
    );
  }
}

/// A sample panel over a busy strip so the slider's effect is visible.
class _GlassPreview extends StatelessWidget {
  const _GlassPreview();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 92,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [p.bgDeep, p.surfaceHigh, p.bgDeep],
                ),
              ),
            ),
            Positioned(
              left: 26,
              top: 14,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.accent,
                ),
              ),
            ),
            Positioned(
              right: 34,
              bottom: -18,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: p.accent, width: 6),
                ),
              ),
            ),
            Center(
              child: GlassSurface(
                radius: 16,
                shadow: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                child: Text('Live preview', style: T.strong(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutSheet extends StatelessWidget {
  const _AboutSheet();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: 6),
      const AltairMark(width: 120),
      const SizedBox(height: 16),
      Text('PROJECT ALTAIR', style: T.display(context).copyWith(fontSize: 22)),
      const SizedBox(height: 4),
      Text('Version ${AppConfig.version}', style: T.small(context)),
      const SizedBox(height: 16),
      Text(
        'The operations app of the Project Altair rover team. See what the '
        'team is working on, time engineering tasks, review completed work, '
        'share notices and reach any member - from one place.\n\n'
        'Robotics · Engineering · Teamwork · Precision · Innovation',
        textAlign: TextAlign.center,
        style: T.body(context),
      ),
      const SizedBox(height: 10),
    ],
  );
}

class _PrivacySheet extends StatelessWidget {
  const _PrivacySheet();

  static const _sections = <(String, String)>[
    (
      'What the app stores',
      'Your User ID, name, role, sub-team and profile picture; the tasks and '
          'notes you create; the times you start and end tasks; and, for '
          'members listed in the directories, a phone number, WhatsApp number '
          'and Messenger link.',
    ),
    (
      'Who can see it',
      'Only signed-in Project Altair team members. Nothing in the app is '
          'public. Administrators can also see an activity log of changes.',
    ),
    (
      'Where it is kept',
      'In the team\'s own Google Firebase project, pictures included. '
          'Passwords are kept by Firebase Authentication only as salted '
          'one-way hashes and can never be read back, not even by an '
          'administrator.',
    ),
    (
      'Alerts',
      'Alerts are worked out on your phone from the team\'s live data while '
          'the app is open. Your alert choices never leave this phone.',
    ),
    (
      'Calls and messages',
      'The Call, WhatsApp and Messenger buttons only open those apps. '
          'Project Altair never sends a message or places a call by itself.',
    ),
    (
      'Your choices',
      'Ask a team administrator to correct or remove your information or '
          'to close your account.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SheetTitle('Privacy policy'),
      for (final section in _sections) ...[
        Text(section.$1, style: T.strong(context)),
        const SizedBox(height: 4),
        Text(section.$2, style: T.body(context)),
        const SizedBox(height: 14),
      ],
    ],
  );
}
