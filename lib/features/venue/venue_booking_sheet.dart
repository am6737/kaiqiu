// venue_booking_sheet.dart — 场馆预约时段选择
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/venue.dart';
import '../../providers.dart';
import '../../services/supabase.dart';
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';
import '../../widgets/primary_button.dart';

class VenueBookingSheet extends ConsumerStatefulWidget {
  final Venue venue;
  const VenueBookingSheet({super.key, required this.venue});

  @override
  ConsumerState<VenueBookingSheet> createState() => _VenueBookingSheetState();
}

class _VenueBookingSheetState extends ConsumerState<VenueBookingSheet> {
  late DateTime _selectedDate;
  String? _selectedStart;
  String? _selectedEnd;
  final _note = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    if (_selectedDate.hour >= 22) {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  List<DateTime> get _dateOptions {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (i) => today.add(Duration(days: i)));
  }

  List<String> get _timeSlots {
    int startH = 8, endH = 22;
    final oh = widget.venue.openingHours;
    if (oh != null && oh.contains('-')) {
      final parts = oh.split('-');
      final sh = int.tryParse(parts[0].split(':')[0]);
      final eh = int.tryParse(parts[1].split(':')[0]);
      if (sh != null) startH = sh;
      if (eh != null) endH = eh;
    }
    final slots = <String>[];
    for (int h = startH; h <= endH; h++) {
      slots.add('${h.toString().padLeft(2, '0')}:00');
      if (h < endH) slots.add('${h.toString().padLeft(2, '0')}:30');
    }
    return slots;
  }

  String _dateName(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '明天';
    if (diff == 2) return '后天';
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[d.weekday - 1];
  }

  String _dateLabel(DateTime d) =>
      '${d.month}/${d.day}';

  Future<void> _submit() async {
    final uid = currentUserId;
    if (uid == null) {
      showToast(context, '请先登录', error: true);
      return;
    }
    if (_selectedStart == null || _selectedEnd == null) {
      showToast(context, '请选择预约时段', error: true);
      return;
    }
    final startIdx = _timeSlots.indexOf(_selectedStart!);
    final endIdx = _timeSlots.indexOf(_selectedEnd!);
    if (endIdx <= startIdx) {
      showToast(context, '结束时间需晚于开始时间', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final freshBookings = await ref
          .read(venuesRepoProvider)
          .bookingsForVenue(widget.venue.id, date: _selectedDate);
      final conflicting = freshBookings.where((b) {
        if (b.status == BookingStatus.cancelled) return false;
        final bsi = _timeSlots.indexOf(b.startTime);
        final bei = _timeSlots.indexOf(b.endTime);
        return bsi < endIdx && bei > startIdx;
      });
      if (conflicting.isNotEmpty) {
        if (mounted) {
          showToast(context, '该时段已被预约，请选择其他时段', error: true);
          ref.invalidate(venueBookingsProvider(
            (venueId: widget.venue.id, date: _selectedDate),
          ));
        }
        return;
      }

      final hours = (endIdx - startIdx) * 0.5;
      final totalCents = (widget.venue.pricePerHourCents * hours).round();
      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      await ref.read(venuesRepoProvider).createBooking({
        'venue_id': widget.venue.id,
        'user_id': uid,
        'date': dateStr,
        'start_time': _selectedStart,
        'end_time': _selectedEnd,
        'total_cents': totalCents,
        'status': 'pending',
        'note': _note.text.trim().isNotEmpty ? _note.text.trim() : null,
      });
      ref.invalidate(myBookingsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(context, '预约提交成功，等待场馆确认', success: true);
    } catch (e) {
      if (!mounted) return;
      showToast(context, '预约失败: $e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bookingsAsync = ref.watch(
      venueBookingsProvider((venueId: widget.venue.id, date: _selectedDate)),
    );

    final bookedSlots = <String>{};
    if (bookingsAsync.hasValue) {
      for (final b in bookingsAsync.value!) {
        if (b.status == BookingStatus.cancelled) continue;
        final si = _timeSlots.indexOf(b.startTime);
        final ei = _timeSlots.indexOf(b.endTime);
        if (si >= 0 && ei > si) {
          for (int i = si; i < ei; i++) {
            bookedSlots.add(_timeSlots[i]);
          }
        }
      }
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.inkMute,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '预约场地',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.venue.name,
              style: TextStyle(fontSize: 13, color: t.inkSub),
            ),
            const SizedBox(height: 16),

            // Date selector
            Text(
              '选择日期',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _dateOptions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final d = _dateOptions[i];
                  final isSelected = _selectedDate.day == d.day &&
                      _selectedDate.month == d.month;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDate = d),
                    child: Container(
                      width: 56,
                      decoration: BoxDecoration(
                        color: isSelected ? t.accent : t.elev2,
                        borderRadius: BorderRadius.circular(t.r2),
                        border: Border.all(
                          color: isSelected ? t.accent : t.line,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _dateName(d),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? t.accentInk : t.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _dateLabel(d),
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? t.accentInk : t.inkSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Time range
            Text(
              '选择时段',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TimeDropdown(
                    label: '开始',
                    value: _selectedStart,
                    slots: _timeSlots,
                    bookedSlots: bookedSlots,
                    onChanged: (v) => setState(() {
                      _selectedStart = v;
                      if (_selectedEnd != null) {
                        final si = _timeSlots.indexOf(v!);
                        final ei = _timeSlots.indexOf(_selectedEnd!);
                        if (ei <= si) _selectedEnd = null;
                      }
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('—', style: TextStyle(color: t.inkSub)),
                ),
                Expanded(
                  child: _TimeDropdown(
                    label: '结束',
                    value: _selectedEnd,
                    slots: _timeSlots,
                    bookedSlots: bookedSlots,
                    onChanged: (v) => setState(() => _selectedEnd = v),
                    minIndex: _selectedStart != null
                        ? _timeSlots.indexOf(_selectedStart!) + 1
                        : 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Price summary
            if (_selectedStart != null && _selectedEnd != null) ...[
              _PriceSummary(
                venue: widget.venue,
                start: _selectedStart!,
                end: _selectedEnd!,
                timeSlots: _timeSlots,
              ),
              const SizedBox(height: 12),
            ],

            // Note
            TextField(
              controller: _note,
              style: TextStyle(fontSize: 13, color: t.ink),
              decoration: InputDecoration(
                hintText: '备注（选填）',
                hintStyle: TextStyle(fontSize: 13, color: t.inkDim),
                filled: true,
                fillColor: t.elev2,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(t.r2),
                  borderSide: BorderSide(color: t.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(t.r2),
                  borderSide: BorderSide(color: t.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(t.r2),
                  borderSide: BorderSide(color: t.accent, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: _submitting ? '提交中…' : '确认预约',
              variant: BtnVariant.primary,
              size: BtnSize.lg,
              full: true,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> slots;
  final Set<String> bookedSlots;
  final ValueChanged<String?> onChanged;
  final int minIndex;

  const _TimeDropdown({
    required this.label,
    this.value,
    required this.slots,
    required this.bookedSlots,
    required this.onChanged,
    this.minIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: t.elev2,
        borderRadius: BorderRadius.circular(t.r2),
        border: Border.all(color: t.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: Text(label, style: TextStyle(fontSize: 13, color: t.inkDim)),
          dropdownColor: t.elev2,
          style: TextStyle(fontSize: 14, color: t.ink),
          items: slots.asMap().entries.where((e) => e.key >= minIndex).map((e) {
            final booked = bookedSlots.contains(e.value);
            return DropdownMenuItem<String>(
              value: e.value,
              enabled: !booked,
              child: Text(
                booked ? '${e.value} (已约)' : e.value,
                style: TextStyle(
                  fontSize: 13,
                  color: booked ? t.inkMute : t.ink,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PriceSummary extends StatelessWidget {
  final Venue venue;
  final String start;
  final String end;
  final List<String> timeSlots;
  const _PriceSummary({
    required this.venue,
    required this.start,
    required this.end,
    required this.timeSlots,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final si = timeSlots.indexOf(start);
    final ei = timeSlots.indexOf(end);
    final hours = (ei - si) * 0.5;
    final total = venue.pricePerHourYuan * hours;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.accentSubtle,
        borderRadius: BorderRadius.circular(t.r2),
      ),
      child: Row(
        children: [
          Text(
            '$start - $end',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: t.ink,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${hours.toStringAsFixed(1)}小时',
            style: TextStyle(fontSize: 12, color: t.inkSub),
          ),
          const Spacer(),
          Text(
            venue.pricePerHourCents > 0
                ? '¥${total.toStringAsFixed(0)}'
                : '免费',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: t.accent,
            ),
          ),
        ],
      ),
    );
  }
}
