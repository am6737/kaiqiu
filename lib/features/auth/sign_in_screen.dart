// sign_in_screen.dart — 登录 / 注册 / 匿名
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase.dart';
import '../../theme/tokens.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';

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

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pwd = _password.text;
    if (email.isEmpty || pwd.length < 6) {
      setState(() => _error = '邮箱不能为空，密码至少 6 位');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      if (_isNewUser) {
        await supabase.auth.signUp(email: email, password: pwd);
      } else {
        await supabase.auth.signInWithPassword(email: email, password: pwd);
      }
      // Router redirect will fire automatically.
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Generate a readable guest name like "游客-K7MX2".
  /// The handle_new_user trigger reads name from raw_user_meta_data, so
  /// passing it here means the profiles row is created with this name.
  String _randomGuestName() {
    const charset = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous 0/O/1/I
    final ms = DateTime.now().millisecondsSinceEpoch;
    final suffix = List.generate(5, (i) {
      return charset[(ms >> (i * 5)) % charset.length];
    }).join();
    return '游客-$suffix';
  }

  Future<void> _anonymous() async {
    setState(() { _busy = true; _error = null; });
    try {
      await supabase.auth.signInAnonymously(
        data: {'name': _randomGuestName()},
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 3),
              _Logo(),
              const SizedBox(height: 16),
              const Text('业余体育社交',
                  style: TextStyle(
                      fontSize: 14, color: T.inkSub, letterSpacing: 0.5)),
              const Spacer(flex: 2),
              _Field(
                controller: _email,
                label: '邮箱',
                keyboardType: TextInputType.emailAddress,
                mono: true,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _password,
                label: '密码 (至少 6 位)',
                obscure: true,
                mono: true,
              ),
              const SizedBox(height: 10),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: T.warnDim,
                    borderRadius: BorderRadius.circular(T.r2),
                    border: Border.all(color: const Color(0x55FF6B35)),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(fontSize: 12, color: T.warn)),
                ),
              const SizedBox(height: 14),
              PrimaryButton(
                label: _busy ? '处理中…' : (_isNewUser ? '注册账号' : '登录'),
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
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 12, color: T.inkSub),
                      children: [
                        TextSpan(text: _isNewUser ? '已有账号？' : '还没账号？'),
                        TextSpan(
                          text: _isNewUser ? '去登录' : '去注册',
                          style: const TextStyle(
                              color: T.live, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: const [
                Expanded(child: Divider(color: T.line)),
                SizedBox(width: 10),
                Label('或'),
                SizedBox(width: 10),
                Expanded(child: Divider(color: T.line)),
              ]),
              const SizedBox(height: 20),
              PrimaryButton(
                label: '游客登录（快速开始）',
                full: true,
                variant: BtnVariant.ghost,
                size: BtnSize.lg,
                disabled: _busy,
                onPressed: _anonymous,
              ),
              const Spacer(flex: 2),
              const Text('继续即表示同意服务条款 · 隐私政策',
                  style: TextStyle(fontSize: 10, color: T.inkDim)),
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
            color: T.live,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: T.live.withValues(alpha: 0.6),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        const Text('开球',
            style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: T.ink,
                letterSpacing: -2)),
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
            color: T.elev2,
            border: Border.all(color: T.line),
            borderRadius: BorderRadius.circular(T.r2),
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
                    color: T.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    fontFamily: mono ? T.fontMono : null,
                    fontFamilyFallback: mono ? T.monoFallbacks : null,
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
