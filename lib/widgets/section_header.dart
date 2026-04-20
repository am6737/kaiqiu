// section_header.dart — 通用 section 标题
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'typography.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsets padding;
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Label(title),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class PageTitleBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;
  const PageTitleBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 14),
      child: Row(
        children: [
          if (onBack != null)
            GestureDetector(
              onTap: onBack,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.arrow_back_ios_new, size: 20, color: T.ink),
              ),
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: T.ink,
                letterSpacing: -0.5,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
