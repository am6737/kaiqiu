// onboarding_screen.dart — 注册后引导页（昵称+头像）
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../services/storage.dart';
import '../../services/supabase.dart';
import '../../theme/app_tokens.dart';
import '../../utils/random_name.dart';
import '../../utils/toast.dart';
import '../../widgets/avatar_picker_sheet.dart';
import '../../widgets/network_avatar.dart';
import '../../widgets/preset_avatars.dart';
import '../../widgets/primary_button.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  late String _avatarUrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.text = generateRandomName();
    _avatarUrl = presetUrl(Random().nextInt(kPresetImageUrls.length));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final result = await showAvatarPickerSheet(
      context,
      current: _avatarUrl,
      name: _name.text,
    );
    if (result == null || !mounted) return;

    if (result == kUploadCustom) {
      final uid = currentUserId;
      if (uid == null) return;
      try {
        final url = await StorageService().pickCropCompressAndUpload(
          bucket: 'avatars',
          pathPrefix: uid,
          square: true,
        );
        if (url != null && mounted) setState(() => _avatarUrl = url);
      } catch (e) {
        if (!mounted) return;
        showToast(
          context,
          '${context.l10n.onboarding_save_fail}: $e',
          error: true,
        );
      }
      return;
    }

    setState(() => _avatarUrl = result);
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final name = _name.text.trim();
    if (name.isEmpty) {
      showToast(context, l.onboarding_name_empty, error: true);
      return;
    }

    final uid = currentUserId;
    if (uid == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(profilesRepoProvider).update(uid, {
        'name': name,
        'avatar_url': _avatarUrl,
      });
      ref.invalidate(myProfileProvider);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        showToast(context, '${l.onboarding_save_fail}: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Text(
                l.onboarding_title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: tokens.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.onboarding_subtitle,
                style: TextStyle(fontSize: 14, color: tokens.inkSub),
              ),
              const Spacer(flex: 2),
              GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    NetworkAvatar(_name.text, url: _avatarUrl, size: 96),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: tokens.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 14,
                          color: tokens.accentInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.onboarding_name_label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tokens.inkSub,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: tokens.elev2,
                      border: Border.all(color: tokens.line),
                      borderRadius: BorderRadius.circular(tokens.r2),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _name,
                            style: TextStyle(
                              color: tokens.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _name.text = generateRandomName()),
                          child: Icon(
                            Icons.casino_outlined,
                            size: 22,
                            color: tokens.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: _busy ? l.common_loading : l.onboarding_submit,
                full: true,
                variant: BtnVariant.primary,
                size: BtnSize.lg,
                disabled: _busy,
                onPressed: _submit,
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
