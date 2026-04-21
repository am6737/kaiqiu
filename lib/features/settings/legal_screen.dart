// legal_screen.dart — 用户协议 / 隐私政策
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../widgets/section_header.dart';
import '../../theme/app_tokens.dart';

class LegalScreen extends StatelessWidget {
  final String kind; // 'terms' | 'privacy'
  const LegalScreen({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (title, body) = switch (kind) {
      'privacy' => (l.legal_privacy_title, l.legal_privacy_body),
      _ => (l.legal_terms_title, l.legal_terms_body),
    };
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            PageTitleBar(title: title, onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                children: [
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.tokens.inkSub,
                      height: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
