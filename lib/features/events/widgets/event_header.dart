import 'package:flutter/material.dart';

import '../../../data/demo_images.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../models/event.dart';
import '../../../services/local_storage.dart';
import '../../../utils/share_helper.dart';
import '../../../widgets/network_cover.dart';
import '../../../widgets/typography.dart';
import '../../../theme/app_tokens.dart';

class EventHeader extends StatelessWidget {
  final Event event;
  final VoidCallback onBack;
  final bool isCreator;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onRegister;
  const EventHeader({
    super.key,
    required this.event,
    required this.onBack,
    this.isCreator = false,
    this.onEdit,
    this.onCancel,
    this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final hue = (event.id.codeUnitAt(0) * 7 + event.id.codeUnitAt(1)) % 360.0;
    final l = context.l10n;
    final (dotColor, pillColor, pillText) = switch (event.status) {
      EventStatus.ongoing => (context.tokens.accent, context.tokens.accent, l.event_status_ongoing),
      EventStatus.registering => (context.tokens.warn, context.tokens.warn, l.event_status_registering),
      EventStatus.completed => (context.tokens.inkDim, context.tokens.inkSub, l.event_status_done),
      EventStatus.scheduling => (context.tokens.warn, context.tokens.warn, l.event_status_scheduling),
      EventStatus.cancelled => (context.tokens.danger, context.tokens.danger, l.event_status_cancelled),
      _ => (context.tokens.inkDim, context.tokens.inkSub, l.event_status_done),
    };
    return Stack(
      children: [
        NetworkCover(
          url: (event.coverUrl?.isNotEmpty ?? false)
              ? event.coverUrl
              : DemoImages.pickCoverFor(event.id),
          fallbackLabel: context.l10n.event_overview_main_visual(event.name),
          height: 240,
          hue: hue,
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.35, 0.65, 1.0],
                colors: [
                  Color(0x80000000),
                  Color(0x40000000),
                  Color(0x66000000),
                  Color(0xCC000000),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: SafeArea(
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xB3FFFFFF),
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 16,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: SafeArea(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCreator &&
                    (event.status == EventStatus.draft ||
                     event.status == EventStatus.registering ||
                     event.status == EventStatus.scheduling))
                  _MoreMenu(
                    event: event,
                    onEdit: onEdit,
                    onCancel: onCancel,
                    onRegister: onRegister,
                  ),
                if (isCreator &&
                    (event.status == EventStatus.draft ||
                     event.status == EventStatus.registering ||
                     event.status == EventStatus.scheduling))
                  const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => shareEvent(event),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xB3FFFFFF),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.ios_share,
                      size: 16,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Label(pillText, color: pillColor),
                  if (event.sub != null && event.sub!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Label('· ${event.sub!}', color: const Color(0xCCFFFFFF)),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                event.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFFFFFF),
                  letterSpacing: -0.6,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoreMenu extends StatelessWidget {
  final Event event;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onRegister;
  const _MoreMenu({
    required this.event,
    this.onEdit,
    this.onCancel,
    this.onRegister,
  });

  void _showSheet(BuildContext context) {
    final l = context.l10n;
    final registered = LocalStore.isEventFavorited(event.id);
    final showRegister = event.status == EventStatus.registering && !registered;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.tokens.elev1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: context.tokens.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _SheetItem(
                icon: Icons.edit_outlined,
                label: l.event_edit,
                onTap: () {
                  Navigator.pop(ctx);
                  onEdit?.call();
                },
              ),
              if (showRegister)
                _SheetItem(
                  icon: Icons.group_add_outlined,
                  label: l.event_cta_register,
                  onTap: () {
                    Navigator.pop(ctx);
                    onRegister?.call();
                  },
                ),
              _SheetItem(
                icon: Icons.cancel_outlined,
                label: l.event_cancel,
                color: context.tokens.danger,
                onTap: () {
                  Navigator.pop(ctx);
                  onCancel?.call();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSheet(context),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xB3FFFFFF),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.more_horiz,
          size: 18,
          color: Color(0xFF1A1A1A),
        ),
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _SheetItem({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tokens.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
