// sign_in_screen.dart — 登录 / 注册 / 匿名
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/l10n_extension.dart';
import '../../services/local_storage.dart';
import '../../services/supabase.dart';
import '../../utils/toast.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';
import '../../theme/app_tokens.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _isNewUser = false;
  bool _remember = false;

  @override
  void initState() {
    super.initState();
    _remember = LocalStore.rememberMe;
    final email = LocalStore.rememberedEmail;
    if (email != null) _email.text = email;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final email = _email.text.trim();
    final pwd = _password.text;
    if (email.isEmpty || pwd.length < 6) {
      setState(() => _error = l.error_password_too_short);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isNewUser) {
        await supabase.auth.signUp(email: email, password: pwd);
      } else {
        await supabase.auth.signInWithPassword(email: email, password: pwd);
      }
      await LocalStore.setRemember(_remember, _remember ? email : null);
      // Router redirect will fire automatically.
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _randomGuestName() {
    const charset = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final ms = DateTime.now().millisecondsSinceEpoch;
    final suffix = List.generate(5, (i) {
      return charset[(ms >> (i * 5)) % charset.length];
    }).join();
    final prefix = mounted ? context.l10n.auth_guest_prefix : '游客-';
    return '$prefix$suffix';
  }

  Future<void> _anonymous() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.auth.signInAnonymously(data: {'name': _randomGuestName()});
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final l = context.l10n;
    final c = TextEditingController(text: _email.text);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.elev1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.auth_reset_title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.tokens.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l.auth_reset_sub,
                style: TextStyle(
                  fontSize: 12,
                  color: context.tokens.inkSub,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: context.tokens.elev2,
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(context.tokens.r2),
                ),
                child: TextField(
                  controller: c,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: context.tokens.ink, fontSize: 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: l.auth_email,
                    hintStyle: TextStyle(color: context.tokens.inkDim),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                label: l.auth_reset_submit,
                full: true,
                variant: BtnVariant.primary,
                size: BtnSize.lg,
                onPressed: () async {
                  try {
                    await supabase.auth.resetPasswordForEmail(c.text.trim());
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (mounted) {
                      showToast(context, l.auth_reset_sent, success: true);
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      showToast(ctx, '${l.auth_reset_failed}: $e', error: true);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 3),
              _Logo(),
              const SizedBox(height: 16),
              Text(
                l.auth_login_sub,
                style: TextStyle(
                  fontSize: 14,
                  color: context.tokens.inkSub,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(flex: 2),
              _Field(
                controller: _email,
                label: l.auth_email,
                keyboardType: TextInputType.emailAddress,
                mono: true,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _password,
                label: l.auth_password,
                obscure: true,
                mono: true,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Checkbox(
                    value: _remember,
                    activeColor: context.tokens.accent,
                    onChanged: (v) => setState(() => _remember = v ?? false),
                    visualDensity: VisualDensity.compact,
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _remember = !_remember),
                    child: Text(
                      l.auth_remember_me,
                      style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _forgotPassword,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        l.auth_forgot_password,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.tokens.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.tokens.warnSubtle,
                    borderRadius: BorderRadius.circular(context.tokens.r2),
                    border: Border.all(color: const Color(0x55FF6B35)),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(fontSize: 12, color: context.tokens.warn),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              PrimaryButton(
                label: _busy
                    ? l.rate_submitting
                    : (_isNewUser ? l.auth_signup_btn : l.auth_login_btn),
                full: true,
                variant: BtnVariant.primary,
                size: BtnSize.lg,
                disabled: _busy,
                onPressed: _submit,
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => setState(() => _isNewUser = !_isNewUser),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _isNewUser
                        ? l.auth_signup_toggle_old
                        : l.auth_signup_toggle_new,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.tokens.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Divider(color: context.tokens.line)),
                  const SizedBox(width: 10),
                  Label(l.auth_or),
                  const SizedBox(width: 10),
                  Expanded(child: Divider(color: context.tokens.line)),
                ],
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: l.auth_anon_btn,
                full: true,
                variant: BtnVariant.ghost,
                size: BtnSize.lg,
                disabled: _busy,
                onPressed: _anonymous,
              ),
              const Spacer(flex: 2),
              Text(
                l.auth_terms_notice,
                style: TextStyle(fontSize: 10, color: context.tokens.inkDim),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(right: 10, top: 18),
          decoration: BoxDecoration(
            color: context.tokens.accent,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(color: context.tokens.accent.withValues(alpha: 0.6), blurRadius: 12),
            ],
          ),
        ),
        Text(
          context.l10n.app_name,
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: context.tokens.ink,
            letterSpacing: -2,
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final bool mono;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    this.obscure = false,
    this.mono = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Label(label),
        const SizedBox(height: 6),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.tokens.elev2,
            border: Border.all(color: context.tokens.line),
            borderRadius: BorderRadius.circular(context.tokens.r2),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  autocorrect: false,
                  enableSuggestions: !obscure,
                  style: TextStyle(
                    color: context.tokens.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    fontFamily: mono ? context.tokens.fontMono : null,
                    fontFamilyFallback: mono ? context.tokens.monoFallbacks : null,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
