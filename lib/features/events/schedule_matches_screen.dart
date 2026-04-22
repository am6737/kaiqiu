import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';
import '../../widgets/primary_button.dart';

class ScheduleMatchesScreen extends ConsumerStatefulWidget {
  final String eventId;
  const ScheduleMatchesScreen({super.key, required this.eventId});

  @override
  ConsumerState<ScheduleMatchesScreen> createState() =>
      _ScheduleMatchesScreenState();
}

class _ScheduleMatchesScreenState
    extends ConsumerState<ScheduleMatchesScreen> {
  List<_MatchSlot> _slots = [];
  bool _generated = false;
  bool _busy = false;

  void _generate(Event event) {
    final template = event.template ?? 'knockout16';
    final slots = <_MatchSlot>[];

    switch (template) {
      case 'knockout16':
        for (var i = 0; i < 8; i++) {
          slots.add(_MatchSlot(round: 'qf', index: i));
        }
        for (var i = 0; i < 4; i++) {
          slots.add(_MatchSlot(round: 'sf', index: i));
        }
        slots.add(_MatchSlot(round: 'final', index: 0));
      case 'group8':
        for (var g = 0; g < 2; g++) {
          for (var i = 0; i < 6; i++) {
            slots.add(_MatchSlot(round: 'group', index: g * 6 + i));
          }
        }
        for (var i = 0; i < 2; i++) {
          slots.add(_MatchSlot(round: 'sf', index: i));
        }
        slots.add(_MatchSlot(round: 'final', index: 0));
      case 'league':
        final maxTeams = event.teamsMax ?? 8;
        final totalMatches = maxTeams * (maxTeams - 1);
        for (var i = 0; i < totalMatches; i++) {
          slots.add(_MatchSlot(round: 'league', index: i));
        }
      default:
        for (var i = 0; i < 15; i++) {
          slots.add(_MatchSlot(round: 'group', index: i));
        }
    }

    setState(() {
      _slots = slots;
      _generated = true;
    });
  }

  Future<void> _confirm(Event event) async {
    setState(() => _busy = true);
    try {
      final rows = _slots.map((s) => {
        'event_id': event.id,
        'round': s.round,
        'team_a_label': s.teamALabel,
        'team_b_label': s.teamBLabel,
        'played_at': s.playedAt?.toUtc().toIso8601String(),
        'status': 'upcoming',
        'done': false,
      }).toList();
      await ref.read(eventsRepoProvider).insertMatches(rows);
      await ref
          .read(eventsRepoProvider)
          .updateEventStatus(event.id, EventStatus.ongoing);
      ref.invalidate(eventMatchesProvider(event.id));
      ref.invalidate(eventDetailProvider(event.id));
      if (mounted) {
        showToast(context, context.l10n.schedule_confirm, success: true);
        context.pop();
      }
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: t.ink),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l.schedule_title,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: t.ink),
        ),
      ),
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (event) => _generated
            ? _SlotList(
                slots: _slots,
                onSlotChanged: (i, slot) =>
                    setState(() => _slots[i] = slot),
              )
            : _GeneratePrompt(
                event: event, onGenerate: () => _generate(event)),
      ),
      bottomNavigationBar: _generated
          ? eventAsync.whenOrNull(
              data: (event) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: PrimaryButton(
                    label: l.schedule_confirm,
                    full: true,
                    size: BtnSize.lg,
                    disabled: _busy,
                    onPressed: () => _confirm(event),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _MatchSlot {
  final String round;
  final int index;
  String? teamALabel;
  String? teamBLabel;
  DateTime? playedAt;

  _MatchSlot({
    required this.round,
    required this.index,
    this.teamALabel, // ignore: unused_element_parameter
    this.teamBLabel, // ignore: unused_element_parameter
    this.playedAt, // ignore: unused_element_parameter
  });
}

class _GeneratePrompt extends StatelessWidget {
  final Event event;
  final VoidCallback onGenerate;
  const _GeneratePrompt({required this.event, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, size: 64, color: t.inkSub),
            const SizedBox(height: 16),
            Text(
              l.schedule_auto_hint(event.template ?? 'knockout16'),
              style: TextStyle(fontSize: 14, color: t.inkSub),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: l.schedule_generate,
              size: BtnSize.lg,
              onPressed: onGenerate,
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotList extends StatelessWidget {
  final List<_MatchSlot> slots;
  final void Function(int index, _MatchSlot slot) onSlotChanged;
  const _SlotList({required this.slots, required this.onSlotChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: slots.length,
      separatorBuilder: (_, ignore) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final slot = slots[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.elev1,
            borderRadius: BorderRadius.circular(t.r2),
            border: Border.all(color: t.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${slot.round.toUpperCase()} #${slot.index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.accent,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Team A',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      style: TextStyle(fontSize: 13, color: t.ink),
                      onChanged: (v) {
                        slot.teamALabel = v.isEmpty ? null : v;
                        onSlotChanged(i, slot);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('vs',
                        style: TextStyle(fontSize: 12, color: t.inkSub)),
                  ),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Team B',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      style: TextStyle(fontSize: 13, color: t.ink),
                      onChanged: (v) {
                        slot.teamBLabel = v.isEmpty ? null : v;
                        onSlotChanged(i, slot);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await _showDateTimePicker(ctx);
                  if (picked != null) {
                    slot.playedAt = picked;
                    onSlotChanged(i, slot);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: t.line),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: t.inkSub),
                      const SizedBox(width: 6),
                      Text(
                        slot.playedAt != null
                            ? _fmtDateTime(slot.playedAt!)
                            : l.schedule_set_time,
                        style: TextStyle(fontSize: 12, color: t.inkSub),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _fmtDateTime(DateTime dt) =>
      '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

Future<DateTime?> _showDateTimePicker(BuildContext context) async {
  final date = await showDatePicker(
    context: context,
    initialDate: DateTime.now().add(const Duration(days: 1)),
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 365)),
  );
  if (date == null) return null;
  if (!context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 15, minute: 0),
  );
  if (time == null) return date;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
