// account_settings_screen.dart — 账号设置
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show UserAttributes;

import '../../l10n/l10n_extension.dart';
import '../../l10n/locale_controller.dart';
import '../../services/local_storage.dart';
import '../../services/supabase.dart';
import '../../utils/toast.dart';
import '../../utils/validators.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/typography.dart';
import '../../theme/app_tokens.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final email = supabase.auth.currentUser?.email ?? '—';
    final langLabel = switch (LocaleController.instance.explicitCode) {
      'zh' => l.settings_lang_zh,
      'en' => l.settings_lang_en,
      _ => l.settings_lang_system,
    };
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            PageTitleBar(
              title: l.settings_account_title,
              onBack: () => context.pop(),
            ),
            _section(
              context,
              children: [
                _row(context,
                  icon: Icons.language,
                  label: l.settings_account_language,
                  trailing: langLabel,
                  onTap: () => _pickLanguage(context),
                ),
                _row(context,
                  icon: Icons.edit_outlined,
                  label: l.settings_account_profile,
                  onTap: () => context.push('/profile/edit'),
                ),
                _row(context,
                  icon: Icons.mail_outline,
                  label: l.settings_account_email,
                  trailing: email,
                  onTap: null,
                ),
                _row(context,
                  icon: Icons.lock_outline,
                  label: l.settings_account_password,
                  onTap: () => _changePassword(context),
                ),
              ],
            ),
            _section(
              context,
              children: [
                _row(context,
                  icon: Icons.notifications_none,
                  label: l.profile_menu_notif,
                  onTap: () => context.push('/settings/notifications'),
                ),
                _row(context,
                  icon: Icons.help_outline,
                  label: l.profile_menu_help,
                  onTap: () => context.push('/settings/help'),
                ),
                _row(context,
                  icon: Icons.info_outline,
                  label: l.profile_menu_about,
                  onTap: () => context.push('/settings/about'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: GestureDetector(
                onTap: () => _logout(context),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.tokens.elev2,
                    border: Border.all(color: context.tokens.line),
                    borderRadius: BorderRadius.circular(context.tokens.r2),
                  ),
                  child: Text(
                    l.settings_account_logout,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.tokens.danger,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: GestureDetector(
                onTap: () => _deleteAccount(context),
                child: Center(
                  child: Text(
                    l.settings_account_delete,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.tokens.inkDim,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, {required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: context.tokens.elev2,
          border: Border.all(color: context.tokens.line),
          borderRadius: BorderRadius.circular(context.tokens.r2),
        ),
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, color: context.tokens.line),
              children[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, {
    required IconData icon,
    required String label,
    String? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.tokens.inkSub),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: context.tokens.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  trailing,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.tokens.inkSub,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 16, color: context.tokens.inkDim),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final l = context.l10n;
    final cur = LocaleController.instance.explicitCode;
    await showModalBottomSheet(
      context: context,
      backgroundColor: context.tokens.elev1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.tokens.inkMute,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l.settings_lang_title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.tokens.ink,
              ),
            ),
            const SizedBox(height: 16),
            for (final opt in [
              (null, l.settings_lang_system),
              ('zh', l.settings_lang_zh),
              ('en', l.settings_lang_en),
            ])
              ListTile(
                title: Text(opt.$2, style: TextStyle(color: context.tokens.ink)),
                trailing: cur == opt.$1
                    ? Icon(Icons.check, color: context.tokens.accent, size: 18)
                    : null,
                onTap: () async {
                  await LocaleController.instance.set(opt.$1);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final l = context.l10n;
    final oldC = TextEditingController();
    final newC = TextEditingController();
    final confC = TextEditingController();
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
                l.settings_account_password,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.tokens.ink,
                ),
              ),
              const SizedBox(height: 16),
              _PwField(
                label: l.settings_account_password_old,
                controller: oldC,
              ),
              _PwField(
                label: l.settings_account_password_new,
                controller: newC,
              ),
              _PwField(
                label: l.settings_account_password_confirm,
                controller: confC,
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: l.common_submit,
                variant: BtnVariant.primary,
                size: BtnSize.lg,
                full: true,
                onPressed: () async {
                  if (validatePassword(newC.text) != null) {
                    showToast(ctx, l.error_password_too_short, error: true);
                    return;
                  }
                  if (newC.text != confC.text) {
                    showToast(
                      ctx,
                      l.settings_account_password_mismatch,
                      error: true,
                    );
                    return;
                  }
                  try {
                    await supabase.auth.updateUser(
                      UserAttributes(password: newC.text),
                    );
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                      showToast(
                        context,
                        l.settings_account_password_updated,
                        success: true,
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      showToast(ctx, '$e', error: true);
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

  Future<void> _logout(BuildContext context) async {
    final l = context.l10n;
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.tokens.elev2,
            content: Text(
              l.profile_logout_confirm,
              style: TextStyle(color: context.tokens.ink),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  l.common_cancel,
                  style: TextStyle(color: context.tokens.inkSub),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  l.settings_account_logout,
                  style: TextStyle(color: context.tokens.danger),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    await supabase.auth.signOut();
    await LocalStore.setRemember(false, null);
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final l = context.l10n;
    final confirmWord = l.settings_account_delete_confirm_word;

    final deleted = await showModalBottomSheet<bool>(
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
          child: _DeleteAccountSheet(confirmWord: confirmWord),
        ),
      ),
    );
    if (deleted == true && context.mounted) {
      showToast(context, l.settings_account_delete_done, success: true);
      context.go('/sign-in');
    }
  }
}

class _PwField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _PwField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(label),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(color: context.tokens.line),
              borderRadius: BorderRadius.circular(context.tokens.r2),
            ),
            child: TextField(
              controller: controller,
              obscureText: true,
              style: TextStyle(color: context.tokens.ink, fontSize: 14),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountSheet extends ConsumerStatefulWidget {
  final String confirmWord;
  const _DeleteAccountSheet({required this.confirmWord});

  @override
  ConsumerState<_DeleteAccountSheet> createState() =>
      _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  bool _loading = false;
  late final TextEditingController _controller;

  bool get _matched => _controller.text.trim() == widget.confirmWord;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_matched || _loading) return;
    setState(() => _loading = true);
    try {
      final res = await supabase.functions.invoke('delete-account');
      if (res.status != 200) {
        final body = res.data is String
            ? jsonDecode(res.data as String)
            : res.data;
        final msg = (body is Map ? body['error'] : null) ??
            'Unexpected error (${res.status})';
        if (mounted) {
          showToast(context, '$msg', error: true);
          setState(() => _loading = false);
        }
        return;
      }
      await LocalStore.clearAll();
      try { await supabase.auth.signOut(); } catch (_) {}
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showToast(context, '$e', error: true);
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.settings_account_delete,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: context.tokens.ink,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l.settings_account_delete_warning,
          style: TextStyle(
            fontSize: 13,
            color: context.tokens.danger,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l.settings_account_delete_input_hint,
          style: TextStyle(
            fontSize: 13,
            color: context.tokens.inkSub,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.tokens.elev2,
            border: Border.all(color: context.tokens.line),
            borderRadius: BorderRadius.circular(context.tokens.r2),
          ),
          child: TextField(
            controller: _controller,
            enabled: !_loading,
            style: TextStyle(color: context.tokens.ink, fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _loading
            ? const Center(child: CircularProgressIndicator())
            : PrimaryButton(
                label: l.settings_account_delete,
                variant: BtnVariant.warn,
                size: BtnSize.lg,
                full: true,
                disabled: !_matched,
                onPressed: _matched ? _submit : null,
              ),
      ],
    );
  }
}
