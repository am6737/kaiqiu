// create_event_screen.dart — 创建赛事 4 步向导
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../services/storage.dart';
import '../../services/supabase.dart';
import '../../utils/toast.dart';
import '../../widgets/photo_halftone.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';
import '../../theme/app_tokens.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  final String? editEventId;
  const CreateEventScreen({super.key, this.editEventId});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  bool _submitting = false;
  int _step = 1;
  String _tpl = 'knockout16';
  final _name = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  final _venue = TextEditingController();
  final _fee = TextEditingController();
  final _prize = TextEditingController();
  DateTime? _deadlineDate;
  final _teamSize = TextEditingController();
  final _maxTeams = TextEditingController();
  String _review = 'auto';
  String? _coverUrl;
  bool _uploadingCover = false;

  Map<String, String?> _errors = {};
  bool _editMode = false;

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
  void initState() {
    super.initState();
    if (widget.editEventId != null) {
      _editMode = true;
      _loadEvent();
    }
  }

  Future<void> _loadEvent() async {
    try {
      final event = await ref.read(eventsRepoProvider).fetch(widget.editEventId!);
      setState(() {
        _tpl = event.template ?? 'knockout16';
        _name.text = event.name;
        _startDate = event.startsAt;
        _endDate = event.endsAt;
        _venue.text = event.sub ?? '';
        _fee.text = event.feeCents != null ? '${event.feeCents! ~/ 100}' : '';
        _prize.text = event.prizeCents != null ? '${event.prizeCents! ~/ 100}' : '';
        _deadlineDate = event.deadline;
        _teamSize.text = '${event.teamSize}';
        _maxTeams.text = event.teamsMax != null ? '${event.teamsMax}' : '';
        _review = event.reviewMode ?? 'auto';
        _coverUrl = event.coverUrl;
      });
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _venue,
      _fee,
      _prize,
      _teamSize,
      _maxTeams,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validateStep(int step) {
    final l = context.l10n;
    final errors = <String, String?>{};

    if (step == 2) {
      if (_name.text.trim().isEmpty) errors['name'] = l.validation_name_required;
      if (_startDate == null) {
        errors['start'] = l.validation_start_required;
      } else if (!_startDate!.isAfter(DateTime.now())) {
        errors['start'] = l.validation_start_future;
      }
      if (_endDate == null) {
        errors['end'] = l.validation_end_required;
      } else if (_startDate != null && !_endDate!.isAfter(_startDate!)) {
        errors['end'] = l.validation_end_after_start;
      }
      if (_venue.text.trim().isEmpty) errors['venue'] = l.validation_venue_required;
      final feeVal = _fee.text.trim();
      if (feeVal.isNotEmpty) {
        final n = int.tryParse(feeVal);
        if (n == null || n < 0) errors['fee'] = l.validation_fee_positive;
      }
      final prizeVal = _prize.text.trim();
      if (prizeVal.isNotEmpty) {
        final n = int.tryParse(prizeVal);
        if (n == null || n < 0) errors['prize'] = l.validation_prize_positive;
      }
    } else if (step == 3) {
      if (_deadlineDate == null) {
        errors['deadline'] = l.validation_deadline_required;
      } else if (_startDate != null && !_deadlineDate!.isBefore(_startDate!)) {
        errors['deadline'] = l.validation_deadline_before_start;
      }
      final tsVal = _teamSize.text.trim();
      if (tsVal.isNotEmpty) {
        final n = int.tryParse(tsVal);
        if (n == null || n <= 0) errors['teamSize'] = l.validation_team_size_positive;
      }
      final mtVal = _maxTeams.text.trim();
      if (mtVal.isNotEmpty) {
        final n = int.tryParse(mtVal);
        if (n == null || n < 2) errors['maxTeams'] = l.validation_max_teams_min;
      }
    }

    setState(() => _errors = errors);
    return errors.isEmpty;
  }

  Future<DateTime?> _pickDateTime({DateTime? initial}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: initial != null
          ? TimeOfDay(hour: initial.hour, minute: initial.minute)
          : const TimeOfDay(hour: 15, minute: 0),
    );
    if (time == null) return DateTime(date.year, date.month, date.day);
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final steps = _stepsList(context);
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.tokens.line, width: 1)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(Icons.close, size: 20, color: context.tokens.ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _editMode ? l.event_edit : l.create_event_title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.tokens.ink,
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
                            color: i + 1 <= _step ? context.tokens.accent : context.tokens.elev3,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(i + 1).toString().padLeft(2, '0')} ${steps[i]}',
                          style: TextStyle(
                            fontFamily: context.tokens.fontMono,
                            fontFamilyFallback: context.tokens.monoFallbacks,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: i + 1 == _step
                                ? context.tokens.accent
                                : i + 1 < _step
                                ? context.tokens.ink
                                : context.tokens.inkDim,
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
        decoration: BoxDecoration(
          color: context.tokens.elev1,
          border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
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
                          if (_step == 1 || _validateStep(_step)) {
                            setState(() => _step++);
                          }
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
      final payload = {
        'creator_id': uid,
        'name': _name.text.trim(),
        'sub': _venue.text.trim().isEmpty ? null : _venue.text.trim(),
        'template': _tpl,
        'team_size': int.tryParse(_teamSize.text) ?? 11,
        'teams_max': int.tryParse(_maxTeams.text) ?? 16,
        'fee_cents': (int.tryParse(_fee.text) ?? 0) * 100,
        'prize_cents': (int.tryParse(_prize.text) ?? 0) * 100,
        'deadline': _deadlineDate?.toIso8601String(),
        'starts_at': _startDate?.toIso8601String(),
        'ends_at': _endDate?.toIso8601String(),
        'review_mode': _review,
        if (_coverUrl != null) 'cover_url': _coverUrl,
      };

      if (_editMode) {
        await ref.read(eventsRepoProvider).updateEvent(widget.editEventId!, payload);
      } else {
        await ref.read(eventsRepoProvider).create(payload);
      }
      ref.invalidate(liveEventsProvider(EventStatus.registering));
      ref.invalidate(myHostedEventsProvider);
      if (!mounted) return;
      showToast(
        context,
        _editMode ? l.event_edit_success : l.create_event_published,
        success: true,
      );
      context.go('/events');
    } catch (e) {
      if (!mounted) return;
      showToast(context, l.create_event_publish_failed('$e'), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.tokens.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.create_event_tpl_subtitle,
            style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
          ),
          const SizedBox(height: 18),
          for (final t in tpls) ...[
            GestureDetector(
              onTap: () => setState(() => _tpl = t.$1),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _tpl == t.$1 ? context.tokens.elev3 : context.tokens.elev2,
                  border: Border.all(color: _tpl == t.$1 ? context.tokens.accent : context.tokens.line),
                  borderRadius: BorderRadius.circular(context.tokens.r3),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CustomPaint(
                        painter: _BracketMiniPainter(t.$1, _tpl == t.$1, inkSub: context.tokens.inkSub, inkMute: context.tokens.inkMute, accent: context.tokens.accent),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.$2,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.tokens.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t.$3,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.tokens.inkSub,
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
                        color: _tpl == t.$1 ? context.tokens.accent : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _tpl == t.$1 ? context.tokens.accent : context.tokens.line,
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.tokens.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 18),
          _Field(label: l.create_event_f_name, controller: _name, errorText: _errors['name']),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: l.create_event_f_start,
                  value: _startDate,
                  errorText: _errors['start'],
                  onTap: () async {
                    final dt = await _pickDateTime(initial: _startDate);
                    if (dt != null) setState(() => _startDate = dt);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                  label: l.create_event_f_end,
                  value: _endDate,
                  errorText: _errors['end'],
                  onTap: () async {
                    final dt = await _pickDateTime(initial: _endDate);
                    if (dt != null) setState(() => _endDate = dt);
                  },
                ),
              ),
            ],
          ),
          _Field(label: l.create_event_f_venue, controller: _venue, errorText: _errors['venue']),
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: l.create_event_f_fee,
                  controller: _fee,
                  prefix: '¥',
                  mono: true,
                  keyboardType: TextInputType.number,
                  errorText: _errors['fee'],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  label: l.create_event_f_prize,
                  controller: _prize,
                  prefix: '¥',
                  mono: true,
                  keyboardType: TextInputType.number,
                  errorText: _errors['prize'],
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.tokens.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 18),
          _DateField(
            label: l.create_event_f_deadline,
            value: _deadlineDate,
            errorText: _errors['deadline'],
            onTap: () async {
              final dt = await _pickDateTime(initial: _deadlineDate);
              if (dt != null) setState(() => _deadlineDate = dt);
            },
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
                        color: _review == opt.$1 ? context.tokens.elev3 : context.tokens.elev2,
                        border: Border.all(
                          color: _review == opt.$1 ? context.tokens.accent : context.tokens.line,
                        ),
                        borderRadius: BorderRadius.circular(context.tokens.r2),
                      ),
                      child: Text(
                        opt.$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _review == opt.$1 ? context.tokens.accent : context.tokens.ink,
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
                  keyboardType: TextInputType.number,
                  errorText: _errors['teamSize'],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  label: l.create_event_f_maxteams,
                  controller: _maxTeams,
                  mono: true,
                  keyboardType: TextInputType.number,
                  errorText: _errors['maxTeams'],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(color: context.tokens.line),
              borderRadius: BorderRadius.circular(context.tokens.r2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events, size: 14, color: context.tokens.warn),
                    const SizedBox(width: 8),
                    Label(l.create_event_organizer_tip_title, color: context.tokens.warn),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l.create_event_organizer_tip_body,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.tokens.inkSub,
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

  String _fmtDate(DateTime dt) => DateFormat('yyyy-MM-dd HH:mm').format(dt);

  Widget _step4() {
    final l = context.l10n;
    final tpls = _tpls(context);
    final tplName = tpls
        .firstWhere((t) => t.$1 == _tpl, orElse: () => tpls[1])
        .$2;
    final prizeWan = (int.tryParse(_prize.text) ?? 0) / 10000;
    final startStr = _startDate != null ? _fmtDate(_startDate!) : '';
    final deadlineStr = _deadlineDate != null ? _fmtDate(_deadlineDate!) : '';
    final configOk = _name.text.trim().isNotEmpty &&
        _startDate != null &&
        _endDate != null &&
        _venue.text.trim().isNotEmpty &&
        _deadlineDate != null;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.create_event_step_preview,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.tokens.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.create_event_preview_subtitle,
            style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _uploadingCover ? null : _pickCover,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.tokens.elev2,
                border: Border.all(color: context.tokens.line),
                borderRadius: BorderRadius.circular(context.tokens.r2),
              ),
              child: Row(
                children: [
                  Icon(
                    _coverUrl == null
                        ? Icons.add_photo_alternate_outlined
                        : Icons.check_circle,
                    size: 18,
                    color: _coverUrl == null ? context.tokens.inkSub : context.tokens.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _coverUrl == null ? '封面（可选）· 点击上传' : '封面已上传',
                      style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
                    ),
                  ),
                  if (_uploadingCover)
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
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(color: context.tokens.line),
              borderRadius: BorderRadius.circular(context.tokens.r3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(context.tokens.r3),
                    topRight: Radius.circular(context.tokens.r3),
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
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: context.tokens.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$tplName · ${_venue.text}',
                        style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _previewStat(
                            l.home_event_kickoff,
                            startStr.length > 5
                                ? startStr.substring(5)
                                : startStr,
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
                          color: context.tokens.elev3,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Label(
                        l.create_event_preview_registered_of_max(
                          _maxTeams.text,
                          deadlineStr.length > 5
                              ? deadlineStr.substring(5)
                              : deadlineStr,
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
              color: configOk ? context.tokens.accentSubtle : context.tokens.elev2,
              border: Border.all(color: configOk ? const Color(0x6600FF85) : context.tokens.line),
              borderRadius: BorderRadius.circular(context.tokens.r2),
            ),
            child: Row(
              children: [
                Icon(
                  configOk ? Icons.check : Icons.warning_amber_rounded,
                  size: 14,
                  color: configOk ? context.tokens.accent : context.tokens.warn,
                ),
                const SizedBox(width: 8),
                Text(
                  l.create_event_preview_config_ok,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: configOk ? context.tokens.accent : context.tokens.warn,
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
            ? BoxDecoration(
                border: Border(left: BorderSide(color: context.tokens.line, width: 1)),
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
  final String? errorText;
  final TextInputType? keyboardType;
  const _Field({
    required this.label,
    required this.controller,
    this.prefix,
    this.mono = false,
    this.errorText,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
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
              color: context.tokens.elev2,
              border: Border.all(color: hasError ? Colors.red : context.tokens.line),
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
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 4),
            Text(
              errorText!,
              style: const TextStyle(fontSize: 11, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final String? errorText;
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final display = value != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(value!)
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(label),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: context.tokens.elev2,
                border: Border.all(color: hasError ? Colors.red : context.tokens.line),
                borderRadius: BorderRadius.circular(context.tokens.r2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      display,
                      style: TextStyle(
                        color: display.isEmpty ? context.tokens.inkDim : context.tokens.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        fontFamily: context.tokens.fontMono,
                        fontFamilyFallback: context.tokens.monoFallbacks,
                      ),
                    ),
                  ),
                  Icon(Icons.calendar_today, size: 16, color: context.tokens.inkSub),
                ],
              ),
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 4),
            Text(
              errorText!,
              style: const TextStyle(fontSize: 11, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}

class _BracketMiniPainter extends CustomPainter {
  final String variant;
  final bool active;
  final Color inkSub;
  final Color inkMute;
  final Color accent;
  _BracketMiniPainter(this.variant, this.active, {required this.inkSub, required this.inkMute, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final c = active ? accent : inkSub;
    final cDim = active ? accent : inkMute;
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
