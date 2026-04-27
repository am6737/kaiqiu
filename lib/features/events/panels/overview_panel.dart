import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../models/event.dart';
import '../../../providers.dart';
import '../../../services/map_launcher.dart';
import '../../../widgets/network_avatar.dart';
import '../../../widgets/typography.dart';
import '../../../theme/app_tokens.dart';
import 'package:go_router/go_router.dart';

class OverviewPanel extends ConsumerWidget {
  final Event event;
  const OverviewPanel({super.key, required this.event});

  bool get _canNavigate => event.lat != null && event.lng != null;

  String get _locationText {
    final parts = <String>[];
    if (event.sub != null && event.sub!.isNotEmpty) parts.add(event.sub!);
    if (event.address != null &&
        event.address!.trim().isNotEmpty &&
        event.address != event.sub) {
      parts.add(event.address!);
    }
    return parts.join(' · ');
  }

  void _openNav(BuildContext context) {
    if (!_canNavigate) return;
    MapLauncher.openNavigation(
      context: context,
      lat: event.lat!,
      lng: event.lng!,
      name: event.sub ?? (event.address ?? ''),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final creatorProfile = event.creatorId != null
        ? ref.watch(profileByIdProvider(event.creatorId!))
        : null;
    return Container(
      padding: const EdgeInsets.all(16),
      color: context.tokens.elev1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${event.name}。',
            style: TextStyle(fontSize: 14, color: context.tokens.ink, height: 1.6),
          ),
          const SizedBox(height: 16),
          Label(l.event_overview_rules),
          const SizedBox(height: 10),
          for (final r in [
            l.event_overview_rule_format,
            l.event_overview_rule_halves,
            l.event_overview_rule_subs,
            l.event_overview_rule_cards,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.tokens.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    r,
                    style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          // Venue section
          if (event.sub != null && event.sub!.isNotEmpty) ...[
            Label(l.event_overview_venue),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.tokens.elev2,
                border: Border.all(color: context.tokens.line),
                borderRadius: BorderRadius.circular(context.tokens.r2),
              ),
              child: Row(
                children: [
                  Icon(Icons.near_me, size: 14, color: context.tokens.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _canNavigate ? () => _openNav(context) : null,
                    style: TextButton.styleFrom(
                      foregroundColor: context.tokens.accent,
                      disabledForegroundColor: context.tokens.inkMute,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    child: Text(l.pickup_detail_navigate),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          Label(l.event_overview_organizer),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: event.creatorId != null
                ? () => context.push('/user/${event.creatorId!}')
                : null,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.tokens.elev2,
                border: Border.all(color: context.tokens.line),
                borderRadius: BorderRadius.circular(context.tokens.r2),
              ),
              child: Row(
                children: [
                  if (creatorProfile != null)
                    creatorProfile.when(
                      data: (p) => NetworkAvatar(
                        p?.name ?? '?',
                        url: p?.avatarUrl,
                        size: 36,
                        square: true,
                      ),
                      loading: () => Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: context.tokens.elev3,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      error: (_, _) => Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: context.tokens.elev3,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.tokens.elev3,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          creatorProfile?.valueOrNull?.name ?? '—',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.tokens.ink,
                          ),
                        ),
                        Label(l.event_overview_organizer_label),
                      ],
                    ),
                  ),
                  if (event.creatorId != null)
                    Icon(Icons.chevron_right,
                        size: 18, color: context.tokens.inkMute),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
