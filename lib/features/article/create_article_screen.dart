// create_article_screen.dart — 写文章
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';

class CreateArticleScreen extends ConsumerStatefulWidget {
  const CreateArticleScreen({super.key});

  @override
  ConsumerState<CreateArticleScreen> createState() =>
      _CreateArticleScreenState();
}

class _CreateArticleScreenState extends ConsumerState<CreateArticleScreen> {
  final _titleCtl = TextEditingController();
  final _summaryCtl = TextEditingController();
  final _bodyCtl = TextEditingController();
  String _category = 'analysis';
  bool _submitting = false;

  bool get _canPublish =>
      !_submitting &&
      _titleCtl.text.trim().isNotEmpty &&
      _bodyCtl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _titleCtl.addListener(_onChanged);
    _bodyCtl.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _titleCtl.dispose();
    _summaryCtl.dispose();
    _bodyCtl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final l = context.l10n;
    final title = _titleCtl.text.trim();
    final body = _bodyCtl.text.trim();

    if (title.isEmpty) {
      showToast(context, l.create_article_title_required, error: true);
      return;
    }
    if (body.isEmpty) {
      showToast(context, l.create_article_body_required, error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final summary = _summaryCtl.text.trim();
      await ref.read(articlesRepoProvider).create(
            title: title,
            body: body,
            category: _category,
            summary: summary.isNotEmpty ? summary : null,
            city: ref.read(cityProvider),
          );
      if (!mounted) return;
      showToast(context, l.create_article_published, success: true);
      ref.invalidate(myArticlesProvider);
      ref.invalidate(discoverFeedProvider);
      ref.invalidate(recommendFeedProvider);
      context.pop();
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;

    final categories = {
      'analysis': l.create_article_cat_analysis,
      'review': l.create_article_cat_review,
      'news': l.create_article_cat_news,
      'opinion': l.create_article_cat_opinion,
    };

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.arrow_back, color: t.ink),
                  ),
                  Expanded(
                    child: Text(
                      l.create_article_title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _canPublish ? _publish : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _canPublish ? t.accent : t.elev3,
                        borderRadius: BorderRadius.circular(t.r2),
                      ),
                      child: Text(
                        l.common_publish,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _canPublish ? t.accentInk : t.inkDim,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Form body ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // Title
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.elev1,
                      borderRadius: BorderRadius.circular(t.r2),
                    ),
                    child: TextField(
                      controller: _titleCtl,
                      style: TextStyle(fontSize: 15, color: t.ink),
                      decoration: InputDecoration(
                        hintText: l.create_article_title_hint,
                        hintStyle: TextStyle(color: t.inkDim),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Category
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.elev1,
                      borderRadius: BorderRadius.circular(t.r2),
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: InputDecoration(
                        labelText: l.create_article_category,
                        labelStyle: TextStyle(color: t.inkSub),
                        border: InputBorder.none,
                      ),
                      dropdownColor: t.elev2,
                      style: TextStyle(fontSize: 15, color: t.ink),
                      icon: Icon(Icons.arrow_drop_down, color: t.inkSub),
                      items: categories.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _category = v ?? 'analysis'),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Summary (optional)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.elev1,
                      borderRadius: BorderRadius.circular(t.r2),
                    ),
                    child: TextField(
                      controller: _summaryCtl,
                      style: TextStyle(fontSize: 15, color: t.ink),
                      decoration: InputDecoration(
                        hintText: l.create_article_summary_hint,
                        hintStyle: TextStyle(color: t.inkDim),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Body
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: t.elev1,
                      borderRadius: BorderRadius.circular(t.r2),
                    ),
                    child: TextField(
                      controller: _bodyCtl,
                      style: TextStyle(fontSize: 15, color: t.ink, height: 1.6),
                      maxLines: null,
                      minLines: 12,
                      decoration: InputDecoration(
                        hintText: l.create_article_body_hint,
                        hintStyle: TextStyle(color: t.inkDim),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
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
