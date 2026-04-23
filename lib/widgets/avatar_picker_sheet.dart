import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../theme/app_tokens.dart';
import 'network_avatar.dart';
import 'preset_avatars.dart';

const kUploadCustom = '__upload_custom__';

Future<String?> showAvatarPickerSheet(
  BuildContext context, {
  String? current,
  String name = '',
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: context.tokens.elev1,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(context.tokens.r3)),
    ),
    builder: (_) => _PickerBody(current: current, name: name),
  );
}

class _PickerBody extends StatelessWidget {
  final String? current;
  final String name;
  const _PickerBody({this.current, required this.name});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l = context.l10n;
    final currentIdx = presetIndexOf(current);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.inkMute,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            NetworkAvatar(name, url: current, size: 96),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.avatar_picker_title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.inkSub,
                ),
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: kPresetImageUrls.length,
              itemBuilder: (ctx, i) {
                final selected = currentIdx == i;
                return GestureDetector(
                  onTap: () => Navigator.pop(context, presetUrl(i)),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            selected ? tokens.accent : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: LayoutBuilder(
                      builder: (_, c) => PresetAvatar(i, size: c.maxWidth),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Divider(color: tokens.line, height: 1),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context, kUploadCustom),
                icon: Icon(Icons.add_a_photo_outlined,
                    size: 20, color: tokens.accent),
                label: Text(
                  l.avatar_picker_upload,
                  style: TextStyle(
                    color: tokens.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
