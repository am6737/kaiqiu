// create_event_screen.dart — 创建赛事 4 步向导
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/event.dart';
import '../../providers.dart';
import '../../services/supabase.dart';
import '../../theme/tokens.dart';
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

  static const _tpls = [
    ('group8', '8队小组赛', '2组4队 单循环 + 交叉淘汰'),
    ('knockout16', '16队淘汰赛', '单败淘汰 4 轮决出冠军'),
    ('wc', '世界杯赛制', '32队 8小组 + 淘汰赛'),
    ('league', '联赛赛制', '主客场双循环积分制'),
  ];

  static const _steps = ['赛事模板', '基本信息', '报名设置', '发布预览'];

  @override
  void dispose() {
    for (final c in [_name, _start, _end, _venue, _fee, _prize,
                     _deadline, _teamSize, _maxTeams]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                        const Text('创建赛事',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: T.ink)),
                        Label('第 $_step 步 · 共 4 步'),
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
                for (int i = 0; i < _steps.length; i++) ...[
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
                          '${(i + 1).toString().padLeft(2, '0')} ${_steps[i]}',
                          style: TextStyle(
                            fontFamily: T.fontMono,
                            fontFamilyFallback: T.monoFallbacks,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: i + 1 == _step
                                ? T.live
                                : i + 1 < _step ? T.ink : T.inkDim,
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
                label: '上一步',
                variant: BtnVariant.secondary,
                size: BtnSize.lg,
                onPressed: () => setState(() => _step--),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: PrimaryButton(
                label: _step < 4
                    ? '下一步'
                    : (_submitting ? '发布中…' : '发布赛事'),
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
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录')),
      );
      return;
    }
    setState(() => _submitting = true);
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
      });
      ref.invalidate(liveEventsProvider(EventStatus.registering));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('赛事已发布'),
          backgroundColor: T.live,
        ),
      );
      context.go('/events');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发布失败: $e')),
      );
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('选择赛事模板',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: T.ink,
                  letterSpacing: -0.3)),
          const SizedBox(height: 4),
          const Text('模板决定赛程结构，稍后可调整',
              style: TextStyle(fontSize: 13, color: T.inkSub)),
          const SizedBox(height: 18),
          for (final t in _tpls) ...[
            GestureDetector(
              onTap: () => setState(() => _tpl = t.$1),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _tpl == t.$1 ? T.elev3 : T.elev2,
                  border: Border.all(
                      color: _tpl == t.$1 ? T.live : T.line),
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
                          Text(t.$2,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: T.ink)),
                          const SizedBox(height: 3),
                          Text(t.$3,
                              style: const TextStyle(
                                  fontSize: 12, color: T.inkSub)),
                        ],
                      ),
                    ),
                    Container(
                      width: 20, height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _tpl == t.$1 ? T.live : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _tpl == t.$1 ? T.live : T.line, width: 1.5),
                      ),
                      child: _tpl == t.$1
                          ? const Icon(Icons.check,
                              size: 12, color: Colors.black)
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('基本信息',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: T.ink,
                  letterSpacing: -0.3)),
          const SizedBox(height: 18),
          _Field(label: '赛事名称', controller: _name),
          Row(
            children: [
              Expanded(
                  child: _Field(
                      label: '开赛日期', controller: _start, mono: true)),
              const SizedBox(width: 10),
              Expanded(
                  child:
                      _Field(label: '结束日期', controller: _end, mono: true)),
            ],
          ),
          _Field(label: '场地', controller: _venue),
          Row(
            children: [
              Expanded(
                  child: _Field(
                      label: '报名费(每队)',
                      controller: _fee,
                      prefix: '¥',
                      mono: true)),
              const SizedBox(width: 10),
              Expanded(
                  child: _Field(
                      label: '总奖金',
                      controller: _prize,
                      prefix: '¥',
                      mono: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _step3() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('报名设置',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: T.ink,
                  letterSpacing: -0.3)),
          const SizedBox(height: 18),
          _Field(label: '报名截止', controller: _deadline, mono: true),
          const Padding(
            padding: EdgeInsets.fromLTRB(0, 16, 0, 8),
            child: Label('审核方式'),
          ),
          Row(
            children: [
              for (final opt in const [
                ('auto', '自动通过'),
                ('manual', '组委会审核'),
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
                            color: _review == opt.$1 ? T.live : T.line),
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
                  child:
                      _Field(label: '每队人数', controller: _teamSize, mono: true)),
              const SizedBox(width: 10),
              Expanded(
                  child:
                      _Field(label: '队伍上限', controller: _maxTeams, mono: true)),
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
                  children: const [
                    Icon(Icons.emoji_events, size: 14, color: T.warn),
                    SizedBox(width: 8),
                    Label('组织者提示', color: T.warn),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '建议保留至少 3 天审核期以便处理队伍资料。开赛后无法修改赛事配置。',
                  style:
                      TextStyle(fontSize: 12, color: T.inkSub, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _step4() {
    final tplName =
        _tpls.firstWhere((t) => t.$1 == _tpl, orElse: () => _tpls[1]).$2;
    final prizeWan =
        (int.tryParse(_prize.text) ?? 0) / 10000;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('发布预览',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: T.ink,
                  letterSpacing: -0.3)),
          const SizedBox(height: 4),
          const Text('确认无误后即可发布，队伍可以开始报名',
              style: TextStyle(fontSize: 13, color: T.inkSub)),
          const SizedBox(height: 18),
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
                  child: PhotoHalftone(
                      label: _name.text,
                      height: 110,
                      hue: 140,
                      variant: HalftoneVariant.lines),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_name.text,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: T.ink)),
                      const SizedBox(height: 4),
                      Text('$tplName · ${_venue.text}',
                          style: const TextStyle(
                              fontSize: 12, color: T.inkSub)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _previewStat('开赛',
                              _start.text.length > 5 ? _start.text.substring(5) : _start.text),
                          _previewStat('队伍', _maxTeams.text, border: true),
                          _previewStat('奖金',
                              '¥${prizeWan.toStringAsFixed(1)}万',
                              border: true),
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
                          '0/${_maxTeams.text} 已报名 · 截止 ${_deadline.text.length > 5 ? _deadline.text.substring(5) : _deadline.text}'),
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
              children: const [
                Icon(Icons.check, size: 14, color: T.live),
                SizedBox(width: 8),
                Text('配置完整，可以发布',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: T.live)),
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
                border: Border(left: BorderSide(color: T.line, width: 1)))
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
                      fontFamilyFallback:
                          mono ? T.monoFallbacks : null,
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
            const Rect.fromLTWH(4, 6, 40, 36), const Radius.circular(2)),
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
