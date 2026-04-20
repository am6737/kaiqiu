// create_event_screen.dart — 创建赛事 4 步向导
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../services/storage.dart';
import '../../services/supabase.dart';
import '../../theme/tokens.dart';
import '../../utils/toast.dart';
import '../../widgets/photo_halftone.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  bool _submitting = false;
  int _step = 1;
  String _tpl = 'knockout16';
  final _name = TextEditingController(text: '2026 龙岗夏季杯');
  final _start = TextEditingController(text: '2026-06-01');
  final _end = TextEditingController(text: '2026-06-15');
  final _venue = TextEditingController(text: '龙岗体育中心');
  final _fee = TextEditingController(text: '500');
  final _prize = TextEditingController(text: '20000');
  final _deadline = TextEditingController(text: '2026-05-25');
  final _teamSize = TextEditingController(text: '11');
  final _maxTeams = TextEditingController(text: '16');
  String _review = 'auto';
  String? _coverUrl;
  bool _uploadingCover = false;

  List<(String, String, String)> _tpls(BuildContext context) {
    final l = context.l10n;
    return [
      ('group8', l.create_event_tpl_group8, l.create_event_tpl_group8_desc),
      (
        'knockout16',
        l.create_event_tpl_knockout16,
        l.create_event_tpl_knockout16_desc,
      ),
      ('wc', l.create_event_tpl_wc, l.create_event_tpl_wc_desc),
      ('league', l.create_event_tpl_league, l.create_event_tpl_league_desc),
    ];
  }

  List<String> _stepsList(BuildContext context) {
    final l = context.l10n;
    return [
      l.create_event_step_template,
      l.create_event_step_basic,
      l.create_event_step_registration,
      l.create_event_step_preview,
    ];
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _start,
      _end,
      _venue,
      _fee,
      _prize,
      _deadline,
      _teamSize,
      _maxTeams,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final steps = _stepsList(context);
    return Scaffold(
      backgroundColor: T.bg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: T.line, width: 1)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.close, size: 20, color: T.ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l.create_event_title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: T.ink,
                          ),
                        ),
                        Label(l.create_event_step_n_of(_step, 4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Progress bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                for (int i = 0; i < steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: i + 1 <= _step ? T.live : T.elev3,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(i + 1).toString().padLeft(2, '0')} ${steps[i]}',
                          style: TextStyle(
                            fontFamily: T.fontMono,
                            fontFamilyFallback: T.monoFallbacks,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: i + 1 == _step
                                ? T.live
                                : i + 1 < _step
                                ? T.ink
                                : T.inkDim,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: _stepContent(),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        decoration: const BoxDecoration(
          color: T.elev1,
          border: Border(top: BorderSide(color: T.line, width: 1)),
        ),
        child: Row(
          children: [
            if (_step > 1) ...[
              PrimaryButton(
                label: l.create_event_cta_prev,
                variant: BtnVariant.secondary,
                size: BtnSize.lg,
                onPressed: () => setState(() => _step--),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: PrimaryButton(
                label: _step < 4
                    ? l.create_event_cta_next
                    : (_submitting
                          ? l.create_event_cta_publishing
                          : l.create_event_cta_publish),
                variant: BtnVariant.primary,
                size: BtnSize.lg,
                full: true,
                onPressed: _submitting
                    ? null
                    : () {
                        if (_step < 4) {
                          setState(() => _step++);
                        } else {
                          _submit();
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepContent() {
    return switch (_step) {
      1 => _step1(),
      2 => _step2(),
      3 => _step3(),
      _ => _step4(),
    };
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      showToast(context, l.create_event_hint_not_logged, error: true);
      return;
    }
    setState(() => _submitting = true);
    await _submitImpl();
  }

  Future<void> _pickCover() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      showToast(
        context,
        context.l10n.create_event_hint_not_logged,
        error: true,
      );
      return;
    }
    setState(() => _uploadingCover = true);
    try {
      final url = await StorageService().pickCropCompressAndUpload(
        bucket: 'event-covers',
        pathPrefix: uid,
        square: false,
      );
      if (url == null) return;
      setState(() => _coverUrl = url);
    } catch (e) {
      if (!mounted) return;
      showToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  Future<void> _submitImpl() async {
    final l = context.l10n;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await ref.read(eventsRepoProvider).create({
        'creator_id': uid,
        'name': _name.text.trim(),
        'sub': _venue.text.trim().isEmpty ? null : _venue.text.trim(),
        'template': _tpl,
        'team_size': int.tryParse(_teamSize.text) ?? 11,
        'teams_max': int.tryParse(_maxTeams.text) ?? 16,
        'fee_cents': (int.tryParse(_fee.text) ?? 0) * 100,
        'prize_cents': (int.tryParse(_prize.text) ?? 0) * 100,
        'deadline': _parseDate(_deadline.text)?.toIso8601String(),
        'starts_at': _parseDate(_start.text)?.toIso8601String(),
        'ends_at': _parseDate(_end.text)?.toIso8601String(),
        if (_coverUrl != null) 'cover_url': _coverUrl,
      });
      ref.invalidate(liveEventsProvider(EventStatus.registering));
      if (!mounted) return;
      showToast(context, l.create_event_published, success: true);
      context.go('/events');
    } catch (e) {
      if (!mounted) return;
      showToast(context, l.create_event_publish_failed('$e'), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  DateTime? _parseDate(String s) {
    try {
      return DateTime.parse(s.trim());
    } catch (_) {
      return null;
    }
  }

  Widget _step1() {
    final l = context.l10n;
    final tpls = _tpls(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.create_event_tpl_title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: T.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.create_event_tpl_subtitle,
            style: const TextStyle(fontSize: 13, color: T.inkSub),
          ),
          const SizedBox(height: 18),
          for (final t in tpls) ...[
            GestureDetector(
              onTap: () => setState(() => _tpl = t.$1),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _tpl == t.$1 ? T.elev3 : T.elev2,
                  border: Border.all(color: _tpl == t.$1 ? T.live : T.line),
                  borderRadius: BorderRadius.circular(T.r3),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CustomPaint(
                        painter: _BracketMiniPainter(t.$1, _tpl == t.$1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.$2,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: T.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t.$3,
                            style: const TextStyle(
                              fontSize: 12,
                              color: T.inkSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _tpl == t.$1 ? T.live : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _tpl == t.$1 ? T.live : T.line,
                          width: 1.5,
                        ),
                      ),
                      child: _tpl == t.$1
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.black,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _step2() {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.create_event_step_basic,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: T.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 18),
          _Field(label: l.create_event_f_name, controller: _name),
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: l.create_event_f_start,
                  controller: _start,
                  mono: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  label: l.create_event_f_end,
                  controller: _end,
                  mono: true,
                ),
              ),
            ],
          ),
          _Field(label: l.create_event_f_venue, controller: _venue),
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: l.create_event_f_fee,
                  controller: _fee,
                  prefix: '¥',
                  mono: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  label: l.create_event_f_prize,
                  controller: _prize,
                  prefix: '¥',
                  mono: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _step3() {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.create_event_step_registration,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: T.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 18),
          _Field(
            label: l.create_event_f_deadline,
            controller: _deadline,
            mono: true,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
            child: Label(l.create_event_review_title),
          ),
          Row(
            children: [
              for (final opt in [
                ('auto', l.create_event_review_auto),
                ('manual', l.create_event_review_manual),
              ]) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _review = opt.$1),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _review == opt.$1 ? T.elev3 : T.elev2,
                        border: Border.all(
                          color: _review == opt.$1 ? T.live : T.line,
                        ),
                        borderRadius: BorderRadius.circular(T.r2),
                      ),
                      child: Text(
                        opt.$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _review == opt.$1 ? T.live : T.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                if (opt.$1 == 'auto') const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: l.create_event_f_teamsize,
                  controller: _teamSize,
                  mono: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  label: l.create_event_f_maxteams,
                  controller: _maxTeams,
                  mono: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: T.elev2,
              border: Border.all(color: T.line),
              borderRadius: BorderRadius.circular(T.r2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events, size: 14, color: T.warn),
                    const SizedBox(width: 8),
                    Label(l.create_event_organizer_tip_title, color: T.warn),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l.create_event_organizer_tip_body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: T.inkSub,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _step4() {
    final l = context.l10n;
    final tpls = _tpls(context);
    final tplName = tpls
        .firstWhere((t) => t.$1 == _tpl, orElse: () => tpls[1])
        .$2;
    final prizeWan = (int.tryParse(_prize.text) ?? 0) / 10000;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.create_event_step_preview,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: T.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.create_event_preview_subtitle,
            style: const TextStyle(fontSize: 13, color: T.inkSub),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _uploadingCover ? null : _pickCover,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: T.elev2,
                border: Border.all(color: T.line),
                borderRadius: BorderRadius.circular(T.r2),
              ),
              child: Row(
                children: [
                  Icon(
                    _coverUrl == null
                        ? Icons.add_photo_alternate_outlined
                        : Icons.check_circle,
                    size: 18,
                    color: _coverUrl == null ? T.inkSub : T.live,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _coverUrl == null ? '封面（可选）· 点击上传' : '封面已上传',
                      style: const TextStyle(fontSize: 12, color: T.inkSub),
                    ),
                  ),
                  if (_uploadingCover)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: T.live,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: T.elev2,
              border: Border.all(color: T.line),
              borderRadius: BorderRadius.circular(T.r3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(T.r3),
                    topRight: Radius.circular(T.r3),
                  ),
                  child: _coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: _coverUrl!,
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => PhotoHalftone(
                            label: _name.text,
                            height: 110,
                            hue: 140,
                            variant: HalftoneVariant.lines,
                          ),
                          errorWidget: (_, _, _) => PhotoHalftone(
                            label: _name.text,
                            height: 110,
                            hue: 140,
                            variant: HalftoneVariant.lines,
                          ),
                        )
                      : PhotoHalftone(
                          label: _name.text,
                          height: 110,
                          hue: 140,
                          variant: HalftoneVariant.lines,
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name.text,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: T.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$tplName · ${_venue.text}',
                        style: const TextStyle(fontSize: 12, color: T.inkSub),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _previewStat(
                            l.home_event_kickoff,
                            _start.text.length > 5
                                ? _start.text.substring(5)
                                : _start.text,
                          ),
                          _previewStat(
                            l.event_kpi_teams,
                            _maxTeams.text,
                            border: true,
                          ),
                          _previewStat(
                            l.event_kpi_prize,
                            l.create_event_preview_prize_wan(
                              prizeWan.toStringAsFixed(1),
                            ),
                            border: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: T.elev3,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Label(
                        l.create_event_preview_registered_of_max(
                          _maxTeams.text,
                          _deadline.text.length > 5
                              ? _deadline.text.substring(5)
                              : _deadline.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: T.liveDim,
              border: Border.all(color: const Color(0x6600FF85)),
              borderRadius: BorderRadius.circular(T.r2),
            ),
            child: Row(
              children: [
                const Icon(Icons.check, size: 14, color: T.live),
                const SizedBox(width: 8),
                Text(
                  l.create_event_preview_config_ok,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: T.live,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewStat(String k, String v, {bool border = false}) {
    return Expanded(
      child: Container(
        padding: border ? const EdgeInsets.only(left: 10) : null,
        decoration: border
            ? const BoxDecoration(
                border: Border(left: BorderSide(color: T.line, width: 1)),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Label(k),
            const SizedBox(height: 2),
            N(v, size: 14, weight: FontWeight.w700),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? prefix;
  final bool mono;
  const _Field({
    required this.label,
    required this.controller,
    this.prefix,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(label),
          const SizedBox(height: 6),
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: T.elev2,
              border: Border.all(color: T.line),
              borderRadius: BorderRadius.circular(T.r2),
            ),
            child: Row(
              children: [
                if (prefix != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: N(prefix!, size: 15, color: T.inkDim),
                  ),
                Expanded(
                  child: TextField(
                    controller: controller,
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
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
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

class _BracketMiniPainter extends CustomPainter {
  final String variant;
  final bool active;
  _BracketMiniPainter(this.variant, this.active);

  @override
  void paint(Canvas canvas, Size size) {
    final c = active ? T.live : T.inkSub;
    final cDim = active ? T.live : T.inkMute;
    final scale = size.width / 48;
    canvas.save();
    canvas.scale(scale);

    final stroke = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    final dim = Paint()..color = cDim;
    final dimStroke = Paint()
      ..color = cDim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4;

    if (variant == 'group8') {
      for (final y in [6.0, 14.0]) {
        canvas.drawRect(Rect.fromLTWH(4, y, 16, 6), stroke);
        canvas.drawRect(Rect.fromLTWH(4, y + 24, 16, 6), stroke);
      }
      canvas.drawLine(const Offset(24, 24), const Offset(44, 24), dimStroke);
      canvas.drawRect(const Rect.fromLTWH(30, 20, 14, 8), stroke);
    } else if (variant == 'knockout16') {
      for (final y in [4.0, 10.0, 18.0, 24.0, 32.0, 38.0]) {
        canvas.drawRect(Rect.fromLTWH(2, y, 10, 3), dim);
      }
      for (final y in [8.0, 22.0, 36.0]) {
        canvas.drawRect(Rect.fromLTWH(14, y, 10, 3), dim);
      }
      for (final y in [16.0, 30.0]) {
        canvas.drawRect(Rect.fromLTWH(26, y, 10, 3), dim);
      }
      canvas.drawRect(const Rect.fromLTWH(38, 24, 10, 3), dim);
    } else if (variant == 'wc') {
      for (int col = 0; col < 4; col++) {
        for (final y in [4.0, 12.0, 20.0, 28.0]) {
          canvas.drawRect(Rect.fromLTWH(2 + col * 6, y, 4, 2), dim);
        }
      }
      canvas.drawLine(const Offset(28, 24), const Offset(46, 24), stroke);
      canvas.drawRect(const Rect.fromLTWH(34, 20, 10, 8), stroke);
    } else {
      // league
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(4, 6, 40, 36),
          const Radius.circular(2),
        ),
        stroke,
      );
      for (final y in [12.0, 18.0, 24.0, 30.0, 36.0]) {
        canvas.drawLine(Offset(4, y), Offset(44, y), dimStroke);
      }
      for (final x in [14.0, 24.0, 34.0]) {
        canvas.drawLine(Offset(x, 6), Offset(x, 42), dimStroke);
      }
      canvas.drawRect(const Rect.fromLTWH(4, 6, 10, 6), dim);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BracketMiniPainter old) =>
      old.variant != variant || old.active != active;
}
