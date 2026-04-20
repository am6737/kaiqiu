// about_screen.dart — 关于开球
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n_extension.dart';
import '../../theme/tokens.dart';
import '../../widgets/section_header.dart';
import '../../widgets/typography.dart';

const _kVersion = '0.1.0+1';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: T.bg,
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
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: T.ink,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                l.settings_about_tagline,
                style: const TextStyle(fontSize: 13, color: T.inkSub),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${l.settings_about_version_label} $_kVersion',
                style: const TextStyle(
                  fontFamily: T.fontMono,
                  fontFamilyFallback: T.monoFallbacks,
                  fontSize: 11,
                  color: T.inkDim,
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
                  color: T.elev2,
                  border: Border.all(color: T.line),
                  borderRadius: BorderRadius.circular(T.r2),
                ),
                child: Text(
                  l.settings_about_team_body,
                  style: const TextStyle(
                    fontSize: 13,
                    color: T.inkSub,
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
                  color: T.elev2,
                  border: Border.all(color: T.line),
                  borderRadius: BorderRadius.circular(T.r2),
                ),
                child: Column(
                  children: [
                    _menuRow(
                      Icons.description_outlined,
                      l.settings_about_terms,
                      () => context.push('/settings/legal/terms'),
                    ),
                    const Divider(height: 1, color: T.line),
                    _menuRow(
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
                    color: T.elev2,
                    border: Border.all(color: T.line),
                    borderRadius: BorderRadius.circular(T.r2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mail_outline, color: T.inkSub, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l.settings_about_email,
                          style: const TextStyle(fontSize: 14, color: T.ink),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: T.inkDim,
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

  Widget _menuRow(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: T.inkSub),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, color: T.ink),
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: T.inkDim),
          ],
        ),
      ),
    );
  }
}
