// about_screen.dart — 关于开球
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n_extension.dart';
import '../../widgets/section_header.dart';
import '../../widgets/typography.dart';
import '../../theme/app_tokens.dart';

const _kVersion = '0.1.0+1';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            PageTitleBar(
              title: l.settings_about_title,
              onBack: () => context.pop(),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF00FF85), Color(0xFF009458)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.sports_soccer,
                  size: 40,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                l.app_name,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: context.tokens.ink,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                l.settings_about_tagline,
                style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${l.settings_about_version_label} $_kVersion',
                style: TextStyle(
                  fontFamily: context.tokens.fontMono,
                  fontFamilyFallback: context.tokens.monoFallbacks,
                  fontSize: 11,
                  color: context.tokens.inkDim,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SectionHeader(title: l.settings_about_team),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.tokens.elev2,
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(context.tokens.r2),
                ),
                child: Text(
                  l.settings_about_team_body,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.tokens.inkSub,
                    height: 1.7,
                  ),
                ),
              ),
            ),
            SectionHeader(title: l.settings_about_legal),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Container(
                decoration: BoxDecoration(
                  color: context.tokens.elev2,
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(context.tokens.r2),
                ),
                child: Column(
                  children: [
                    _menuRow(
                      context,
                      Icons.description_outlined,
                      l.settings_about_terms,
                      () => context.push('/settings/legal/terms'),
                    ),
                    Divider(height: 1, color: context.tokens.line),
                    _menuRow(
                      context,
                      Icons.shield_outlined,
                      l.settings_about_privacy,
                      () => context.push('/settings/legal/privacy'),
                    ),
                  ],
                ),
              ),
            ),
            SectionHeader(title: l.settings_about_contact),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: GestureDetector(
                onTap: () => launchUrl(
                  Uri(scheme: 'mailto', path: l.settings_about_email),
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.tokens.elev2,
                    border: Border.all(color: context.tokens.line),
                    borderRadius: BorderRadius.circular(context.tokens.r2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.mail_outline, color: context.tokens.inkSub, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l.settings_about_email,
                          style: TextStyle(fontSize: 14, color: context.tokens.ink),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: context.tokens.inkDim,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(child: Label('© 2026 Kaiqiu · GameOn')),
          ],
        ),
      ),
    );
  }

  Widget _menuRow(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.tokens.inkSub),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, color: context.tokens.ink),
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: context.tokens.inkDim),
          ],
        ),
      ),
    );
  }
}
