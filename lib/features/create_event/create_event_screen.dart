// create_event_screen.dart — 创建赛事 4 步向导
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../services/storage.dart';
import '../../services/supabase.dart';
import '../../utils/toast.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';
import '../../theme/app_tokens.dart';
import 'step_template.dart';
import 'step_basic_info.dart';
import 'step_registration.dart';
import 'step_preview.dart';

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
      1 => StepTemplate(
          selectedTemplate: _tpl,
          onTemplateChanged: (t) => setState(() => _tpl = t),
        ),
      2 => StepBasicInfo(
          nameController: _name,
          startDate: _startDate,
          endDate: _endDate,
          venueController: _venue,
          feeController: _fee,
          prizeController: _prize,
          errors: _errors,
          onPickStart: () async {
            final dt = await _pickDateTime(initial: _startDate);
            if (dt != null) setState(() => _startDate = dt);
          },
          onPickEnd: () async {
            final dt = await _pickDateTime(initial: _endDate);
            if (dt != null) setState(() => _endDate = dt);
          },
        ),
      3 => StepRegistration(
          deadlineDate: _deadlineDate,
          review: _review,
          teamSizeController: _teamSize,
          maxTeamsController: _maxTeams,
          errors: _errors,
          onReviewChanged: (r) => setState(() => _review = r),
          onPickDeadline: () async {
            final dt = await _pickDateTime(initial: _deadlineDate);
            if (dt != null) setState(() => _deadlineDate = dt);
          },
        ),
      _ => StepPreview(
          selectedTemplate: _tpl,
          eventName: _name.text,
          venueName: _venue.text,
          prizeText: _prize.text,
          maxTeamsText: _maxTeams.text,
          startDate: _startDate,
          deadlineDate: _deadlineDate,
          coverUrl: _coverUrl,
          uploadingCover: _uploadingCover,
          onPickCover: _pickCover,
        ),
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

}
