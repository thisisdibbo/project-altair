import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../splash/splash_screen.dart';
import 'join_request.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userId = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _userId.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(_userId.text, _password.text);
      TextInput.finishAutofillContext();
    } catch (e) {
      Haptics.heavy();
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final remember = ref.watch(settingsProvider.select((s) => s.rememberMe));
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LogoSlot(slot: LogoFlight.loginSlot, width: 118),
                    const SizedBox(height: 18),
                    Text(
                      'PROJECT',
                      style: T.display(
                        context,
                      ).copyWith(fontSize: 17, letterSpacing: 4),
                    ),
                    Text(
                      'ALTAIR',
                      style: T.display(
                        context,
                      ).copyWith(fontSize: 30, letterSpacing: 5),
                    ),
                    const SizedBox(height: 6),
                    Text('Rover team operations', style: T.small(context)),
                    const SizedBox(height: 28),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 620),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                          offset: Offset(0, 22 * (1 - v)),
                          child: child,
                        ),
                      ),
                      child: GlassSurface(
                        padding: const EdgeInsets.all(22),
                        child: Form(
                          key: _formKey,
                          child: AutofillGroup(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AltairTextField(
                                  controller: _userId,
                                  label: 'User ID',
                                  hint: 'Issued by your administrator',
                                  icon: Icons.badge_outlined,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.username],
                                  enabled: !_busy,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? 'Enter your User ID'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                AltairTextField(
                                  controller: _password,
                                  label: 'Password',
                                  icon: Icons.lock_outline_rounded,
                                  obscure: _obscure,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  enabled: !_busy,
                                  onSubmitted: (_) => _submit(),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Enter your password'
                                      : null,
                                  suffix: IconButton(
                                    tooltip: _obscure
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                      color: p.textFaint,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    AltairSwitch(
                                      value: remember,
                                      onChanged: ref
                                          .read(settingsProvider.notifier)
                                          .setRememberMe,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Remember me on this phone',
                                        style: T.body(context),
                                      ),
                                    ),
                                  ],
                                ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeOutCubic,
                                  child: _error == null
                                      ? const SizedBox(width: double.infinity)
                                      : Container(
                                          width: double.infinity,
                                          margin: const EdgeInsets.only(
                                            top: 16,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            color: p.ember.withValues(
                                              alpha: 0.12,
                                            ),
                                            border: Border.all(
                                              color: p.ember.withValues(
                                                alpha: 0.5,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            _error!,
                                            style: T.small(
                                              context,
                                            ).copyWith(color: p.ember),
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 22),
                                PrimaryButton(
                                  label: 'Sign in',
                                  icon: Icons.login_rounded,
                                  busy: _busy,
                                  onPressed: _submit,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    GhostButton(
                      label: 'Request an account',
                      icon: Icons.person_add_alt_1_outlined,
                      expand: false,
                      onPressed: _busy ? null : () => showCreateLogin(context),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'New to the team? Request an account and an '
                      'administrator will approve it.\n'
                      'Forgot your password? Ask the administrator.',
                      textAlign: TextAlign.center,
                      style: T.small(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
