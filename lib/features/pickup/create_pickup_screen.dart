// create_pickup_screen.dart — 发起约球
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
import '../../utils/validators.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/typography.dart';

class CreatePickupScreen extends ConsumerStatefulWidget {
  const CreatePickupScreen({super.key});

  @override
  ConsumerState<CreatePickupScreen> createState() => _CreatePickupScreenState();
}

class _CreatePickupScreenState extends ConsumerState<CreatePickupScreen> {
  final _venue = TextEditingController(text: '莲花山足球场');
  final _address = TextEditingController();
  final _start = TextEditingController(text: _defaultStart());
  final _duration = TextEditingController(text: '90');
  final _total = TextEditingController(text: '11');
  final _fee = TextEditingController(text: '50');
  String _level = '中级';
  String _formation = '4-3-3';
  String _fieldType = '11人制';
  bool _submitting = false;
  String? _venuePhotoUrl;
  bool _uploadingPhoto = false;

  Future<void> _pickVenuePhoto() async {
    final uid = currentUserId;
    if (uid == null) {
      showToast(context, context.l10n.error_please_login, error: true);
      return;
    }
    setState(() => _uploadingPhoto = true);
    try {
      final url = await StorageService().pickCropCompressAndUpload(
        bucket: 'pickup-photos',
        pathPrefix: uid,
        square: false,
      );
      if (url == null) return;
      setState(() => _venuePhotoUrl = url);
    } catch (e) {
      if (!mounted) return;
      showToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  static String _defaultStart() {
    final d = DateTime.now().add(const Duration(days: 1));
    final s = d.copyWith(hour: 19, minute: 30, second: 0, millisecond: 0);
    return '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')} 19:30';
  }

  @override
  void dispose() {
    for (final c in [_venue, _address, _start, _duration, _total, _fee]) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime? _parseStart(String s) {
    try {
      final parts = s.trim().split(' ');
      if (parts.length != 2) return null;
      final d = DateTime.parse(parts[0]);
      final hm = parts[1].split(':');
      if (hm.length != 2) return null;
      return DateTime(
        d.year,
        d.month,
        d.day,
        int.parse(hm[0]),
        int.parse(hm[1]),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final uid = currentUserId;
    if (uid == null) {
      showToast(context, l.error_please_login, error: true);
      return;
    }
    if (validateRequired(_venue.text) != null) {
      showToast(context, l.error_required_field, error: true);
      return;
    }
    final startAt = _parseStart(_start.text);
    if (startAt == null) {
      showToast(context, l.error_invalid_date, error: true);
      return;
    }
    final total = int.tryParse(_total.text.trim()) ?? 11;
    final durationMin = int.tryParse(_duration.text.trim()) ?? 90;
    final feeCents = (int.tryParse(_fee.text.trim()) ?? 0) * 100;
    setState(() => _submitting = true);
    try {
      await ref
          .read(pickupsRepoProvider)
          .createWithSlots(
            payload: {
              'host_id': uid,
              'venue': _venue.text.trim(),
              if (_address.text.trim().isNotEmpty)
                'address': _address.text.trim(),
              'start_at': startAt.toUtc().toIso8601String(),
              'duration_min': durationMin,
              'total': total,
              'need': total,
              'level': _level,
              'fee_cents': feeCents,
              'formation': _formation,
              'field_type': _fieldType,
              'status': 'open',
              if (_venuePhotoUrl != null) 'venue_photo_url': _venuePhotoUrl,
            },
            totalSlots: total,
            formation: _formation,
          );
      ref.invalidate(livePickupsProvider);
      ref.invalidate(myHostedPickupsProvider);
      if (!mounted) return;
      showToast(context, l.pickup_create_success, success: true);
      context.go('/pickup');
    } catch (e) {
      if (!mounted) return;
      showToast(context, '${l.error_unknown}: $e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
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
              title: l.pickup_create_title,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  _Field(label: l.pickup_create_venue, controller: _venue),
                  _Field(
                    label: l.pickup_create_address,
                    controller: _address,
                    hint: l.pickup_create_address_hint,
                  ),
                  _Field(
                    label: l.pickup_create_start_at,
                    controller: _start,
                    onTap: () => _pickDateTime(_start),
                    readOnly: true,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          label: l.pickup_create_duration_min,
                          controller: _duration,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      Expanded(
                        child: _Field(
                          label: l.pickup_create_total,
                          controller: _total,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  _Field(
                    label: l.pickup_create_fee,
                    controller: _fee,
                    keyboardType: TextInputType.number,
                    prefix: '¥',
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Label(l.pickup_create_level),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final lv in [
                              ('新手', l.level_beginner),
                              ('初级', l.level_novice),
                              ('中级', l.level_mid),
                              ('高级', l.level_pro),
                            ])
                              _Chip(
                                label: lv.$2,
                                active: _level == lv.$1,
                                onTap: () => setState(() => _level = lv.$1),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Label(l.pickup_create_formation),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final f in const ['4-3-3', '4-4-2', '3-5-2'])
                              _Chip(
                                label: f,
                                active: _formation == f,
                                onTap: () => setState(() => _formation = f),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Label(l.pickup_create_field_type),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final f in [
                              ('5人制', l.field_5),
                              ('7人制', l.field_7),
                              ('8人制', l.field_8),
                              ('11人制', l.field_11),
                            ])
                              _Chip(
                                label: f.$2,
                                active: _fieldType == f.$1,
                                onTap: () => setState(() => _fieldType = f.$1),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: GestureDetector(
                      onTap: _uploadingPhoto ? null : _pickVenuePhoto,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: context.tokens.elev2,
                          border: Border.all(color: context.tokens.line),
                          borderRadius: BorderRadius.circular(context.tokens.r2),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _venuePhotoUrl == null
                                  ? Icons.add_photo_alternate_outlined
                                  : Icons.check_circle,
                              size: 18,
                              color: _venuePhotoUrl == null ? context.tokens.inkSub : context.tokens.accent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _venuePhotoUrl == null
                                    ? '场地照片（可选）· 点击上传'
                                    : '已上传场地照片',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.tokens.inkSub,
                                ),
                              ),
                            ),
                            if (_uploadingPhoto)
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.tokens.accent,
                                ),
                              ),
                          ],
                        ),
                      ),
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
                label: _submitting ? l.rate_submitting : l.pickup_create_submit,
                variant: BtnVariant.primary,
                size: BtnSize.lg,
                full: true,
                onPressed: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime(TextEditingController c) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 30),
    );
    if (t == null) return;
    c.text =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() {});
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? prefix;
  final String? hint;
  final VoidCallback? onTap;
  final bool readOnly;
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.prefix,
    this.hint,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
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
            child: Row(
              children: [
                if (prefix != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: N(prefix!, size: 15, color: context.tokens.inkDim),
                  ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    readOnly: readOnly,
                    onTap: onTap,
                    style: TextStyle(color: context.tokens.ink, fontSize: 14),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                      hintText: hint,
                      hintStyle:
                          TextStyle(color: context.tokens.inkDim, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? context.tokens.accentSubtle : context.tokens.elev2,
          border: Border.all(color: active ? context.tokens.accent : context.tokens.line),
          borderRadius: BorderRadius.circular(999),
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
