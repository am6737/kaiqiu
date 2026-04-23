// step_preview.dart — Step 4: preview and publish
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n_extension.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/photo_halftone.dart';
import '../../widgets/typography.dart';

class StepPreview extends StatelessWidget {
  final String selectedTemplate;
  final String eventName;
  final String venueName;
  final String prizeText;
  final String maxTeamsText;
  final DateTime? startDate;
  final DateTime? deadlineDate;
  final String? coverUrl;
  final bool uploadingCover;
  final VoidCallback onPickCover;

  const StepPreview({
    super.key,
    required this.selectedTemplate,
    required this.eventName,
    required this.venueName,
    required this.prizeText,
    required this.maxTeamsText,
    required this.startDate,
    required this.deadlineDate,
    required this.coverUrl,
    required this.uploadingCover,
    required this.onPickCover,
  });

  String _fmtDate(DateTime dt) => DateFormat('yyyy-MM-dd HH:mm').format(dt);

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

  Widget _previewStat(BuildContext context, String k, String v, {bool border = false}) {
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tpls = _tpls(context);
    final tplName = tpls
        .firstWhere((t) => t.$1 == selectedTemplate, orElse: () => tpls[1])
        .$2;
    final prizeWan = (int.tryParse(prizeText) ?? 0) / 10000;
    final startStr = startDate != null ? _fmtDate(startDate!) : '';
    final deadlineStr = deadlineDate != null ? _fmtDate(deadlineDate!) : '';
    final configOk = eventName.trim().isNotEmpty &&
        startDate != null &&
        venueName.trim().isNotEmpty &&
        deadlineDate != null;
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
            onTap: uploadingCover ? null : onPickCover,
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
                    coverUrl == null
                        ? Icons.add_photo_alternate_outlined
                        : Icons.check_circle,
                    size: 18,
                    color: coverUrl == null ? context.tokens.inkSub : context.tokens.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      coverUrl == null ? '封面（可选）· 点击上传' : '封面已上传',
                      style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
                    ),
                  ),
                  if (uploadingCover)
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
                  child: coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: coverUrl!,
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => PhotoHalftone(
                            label: eventName,
                            height: 110,
                            hue: 140,
                            variant: HalftoneVariant.lines,
                          ),
                          errorWidget: (_, _, _) => PhotoHalftone(
                            label: eventName,
                            height: 110,
                            hue: 140,
                            variant: HalftoneVariant.lines,
                          ),
                        )
                      : PhotoHalftone(
                          label: eventName,
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
                        eventName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: context.tokens.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$tplName · $venueName',
                        style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _previewStat(
                            context,
                            l.home_event_kickoff,
                            startStr.length > 5
                                ? startStr.substring(5)
                                : startStr,
                          ),
                          _previewStat(
                            context,
                            l.event_kpi_teams,
                            maxTeamsText,
                            border: true,
                          ),
                          _previewStat(
                            context,
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
                          maxTeamsText,
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
}
