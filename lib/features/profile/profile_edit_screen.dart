// profile_edit_screen.dart — 编辑资料
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../services/storage.dart';
import '../../services/supabase.dart';
import '../../theme/tokens.dart';
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';
import '../../widgets/network_avatar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/typography.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _name = TextEditingController();
  final _handle = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _height = TextEditingController();
  String? _position;
  String? _foot;
  String? _avatarUrl;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = currentUserId;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final p = await ref.read(profilesRepoProvider).fetch(uid);
    if (!mounted) return;
    setState(() {
      _name.text = p?.name ?? '';
      _handle.text = p?.handle ?? '';
      _city.text = p?.city ?? '';
      _district.text = p?.district ?? '';
      _height.text = (p?.height ?? '').toString();
      _position = p?.position;
      _foot = p?.foot;
      _avatarUrl = p?.avatarUrl;
      _loading = false;
    });
  }

  Future<void> _pickAvatar() async {
    final uid = currentUserId;
    if (uid == null) {
      showToast(context, context.l10n.error_please_login, error: true);
      return;
    }
    setState(() => _uploadingAvatar = true);
    try {
      final url = await StorageService().pickCropCompressAndUpload(
        bucket: 'avatars',
        pathPrefix: uid,
        square: true,
      );
      if (url == null) return;
      await ref.read(profilesRepoProvider).update(uid, {'avatar_url': url});
      if (!mounted) return;
      setState(() => _avatarUrl = url);
      ref.invalidate(myProfileProvider);
    } catch (e) {
      if (!mounted) return;
      showToast(
        context,
        '${context.l10n.profile_edit_save_fail}: $e',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    _city.dispose();
    _district.dispose();
    _height.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = currentUserId;
    if (uid == null) {
      showToast(context, context.l10n.error_please_login, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(profilesRepoProvider).update(uid, {
        'name': _name.text.trim().isEmpty ? null : _name.text.trim(),
        'handle': _handle.text.trim().isEmpty ? null : _handle.text.trim(),
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'district': _district.text.trim().isEmpty
            ? null
            : _district.text.trim(),
        'position': _position,
        'foot': _foot,
        'height': int.tryParse(_height.text.trim()),
      });
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      showToast(context, context.l10n.profile_edit_save_ok, success: true);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      showToast(
        context,
        '${context.l10n.profile_edit_save_fail}: $e',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            PageTitleBar(
              title: l.profile_edit_title,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(color: context.tokens.accent),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 120),
                      children: [
                        _avatarRow(context),
                        _Field(label: l.profile_edit_name, controller: _name),
                        _Field(
                          label: l.profile_edit_handle,
                          controller: _handle,
                        ),
                        _Field(label: l.profile_edit_city, controller: _city),
                        _Field(
                          label: l.profile_edit_district,
                          controller: _district,
                        ),
                        _Field(
                          label: l.profile_edit_height,
                          controller: _height,
                          keyboardType: TextInputType.number,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Label(l.profile_edit_foot),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  for (final f in [
                                    ('left', l.profile_edit_foot_left),
                                    ('right', l.profile_edit_foot_right),
                                    ('both', l.profile_edit_foot_both),
                                  ]) ...[
                                    Expanded(
                                      child: _ChoiceBtn(
                                        label: f.$2,
                                        active: _foot == f.$1,
                                        onTap: () =>
                                            setState(() => _foot = f.$1),
                                      ),
                                    ),
                                    if (f.$1 != 'both')
                                      const SizedBox(width: 8),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Label(l.profile_edit_position),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final p in _positions(l))
                                    _ChoiceBtn(
                                      label: p.$2,
                                      active: _position == p.$1,
                                      onTap: () =>
                                          setState(() => _position = p.$1),
                                      expand: false,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: context.tokens.elev1,
                border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
              ),
              child: PrimaryButton(
                label: _saving ? l.rate_submitting : l.common_save,
                variant: BtnVariant.primary,
                size: BtnSize.lg,
                full: true,
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<(String, String)> _positions(dynamic l) => [
    ('GK', l.profile_edit_position_opt_gk),
    ('CB', l.profile_edit_position_opt_cb),
    ('LB', l.profile_edit_position_opt_lb),
    ('RB', l.profile_edit_position_opt_rb),
    ('CM', l.profile_edit_position_opt_cm),
    ('CAM', l.profile_edit_position_opt_cam),
    ('CDM', l.profile_edit_position_opt_cdm),
    ('LW', l.profile_edit_position_opt_lw),
    ('RW', l.profile_edit_position_opt_rw),
    ('CF', l.profile_edit_position_opt_cf),
    ('ST', l.profile_edit_position_opt_st),
  ];

  Widget _avatarRow(BuildContext context) {
    final l = context.l10n;
    final n = _name.text.trim().isEmpty ? '?' : _name.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: _uploadingAvatar ? null : _pickAvatar,
            child: Stack(
              children: [
                NetworkAvatar(n, url: _avatarUrl, size: 56),
                if (_uploadingAvatar)
                  Positioned.fill(
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.tokens.accent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _uploadingAvatar ? null : _pickAvatar,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.profile_edit_avatar,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.tokens.inkSub,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l.profile_edit_avatar_hint,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.tokens.inkDim,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool expand;
  const _ChoiceBtn({
    required this.label,
    required this.active,
    required this.onTap,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? context.tokens.accentSubtle : context.tokens.elev2,
          border: Border.all(color: active ? context.tokens.accent : context.tokens.line),
          borderRadius: BorderRadius.circular(T.r2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? context.tokens.accent : context.tokens.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
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
              borderRadius: BorderRadius.circular(T.r2),
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
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
