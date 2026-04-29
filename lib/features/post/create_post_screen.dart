import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _bodyCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final _matchCountCtrl = TextEditingController();
  final _winCountCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();

  final List<String> _tags = [];
  bool _showStats = false;
  bool _submitting = false;

  bool get _canPublish => !_submitting && _bodyCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _bodyCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _tagCtrl.dispose();
    _matchCountCtrl.dispose();
    _winCountCtrl.dispose();
    _durationCtrl.dispose();
    _venueCtrl.dispose();
    super.dispose();
  }

  void _addTag([String? label]) {
    final text = (label ?? _tagCtrl.text).trim();
    if (text.isEmpty || _tags.contains(text)) return;
    setState(() => _tags.add(text));
    if (label == null) _tagCtrl.clear();
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  void _toggleHotTag(String tag) {
    if (_tags.contains(tag)) {
      _removeTag(tag);
    } else {
      _addTag(tag);
    }
  }

  Future<void> _publish() async {
    final l = context.l10n;
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) {
      showToast(context, l.create_post_body_required, error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(postsRepoProvider).create(
            body: body,
            tags: _tags,
            matchCount:
                _showStats ? int.tryParse(_matchCountCtrl.text.trim()) : null,
            winCount:
                _showStats ? int.tryParse(_winCountCtrl.text.trim()) : null,
            playDuration:
                _showStats ? int.tryParse(_durationCtrl.text.trim()) : null,
            venue: _showStats ? _venueCtrl.text.trim() : null,
            city: ref.read(cityProvider),
          );

      ref.invalidate(myActivitiesProvider);
      ref.invalidate(discoverFeedProvider);
      ref.invalidate(recommendFeedProvider);

      if (mounted) {
        showToast(context, l.create_post_published, success: true);
        context.pop();
      }
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
                      l.create_post_title,
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

            // ── Scrollable content ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ── Body input ──
                    Container(
                      decoration: BoxDecoration(
                        color: t.elev1,
                        borderRadius: BorderRadius.circular(t.r2),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _bodyCtrl,
                        maxLines: null,
                        minLines: 5,
                        style: TextStyle(fontSize: 15, color: t.ink),
                        decoration: InputDecoration.collapsed(
                          hintText: l.create_post_body_hint,
                          hintStyle: TextStyle(color: t.inkDim),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Selected tags ──
                    if (_tags.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tags
                            .map((tag) => Chip(
                                  label: Text(tag,
                                      style: TextStyle(
                                          fontSize: 13, color: t.ink)),
                                  deleteIcon: Icon(Icons.close,
                                      size: 16, color: t.inkSub),
                                  onDeleted: () => _removeTag(tag),
                                  backgroundColor: t.elev2,
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(t.r1),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Tag input ──
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: t.elev1,
                              borderRadius: BorderRadius.circular(t.r2),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            child: TextField(
                              controller: _tagCtrl,
                              style:
                                  TextStyle(fontSize: 14, color: t.ink),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: l.create_post_tags_hint,
                                hintStyle: TextStyle(color: t.inkDim),
                              ),
                              onSubmitted: (_) => _addTag(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _addTag,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: t.accent,
                              borderRadius: BorderRadius.circular(t.r2),
                            ),
                            child: Icon(Icons.add,
                                color: t.accentInk, size: 20),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Hot tags ──
                    Text(
                      l.create_post_hot_tags,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: t.inkSub,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildHotTags(t),

                    const SizedBox(height: 20),

                    // ── Activity data toggle ──
                    Container(
                      decoration: BoxDecoration(
                        color: t.elev1,
                        borderRadius: BorderRadius.circular(t.r2),
                      ),
                      child: SwitchListTile(
                        title: Text(
                          l.create_post_activity_toggle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: t.ink,
                          ),
                        ),
                        value: _showStats,
                        activeTrackColor: t.accentSubtle,
                        activeThumbColor: t.accent,
                        onChanged: (v) => setState(() => _showStats = v),
                      ),
                    ),

                    // ── Stats fields ──
                    if (_showStats) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberField(
                              controller: _matchCountCtrl,
                              label: l.create_post_match_count,
                              tokens: t,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNumberField(
                              controller: _winCountCtrl,
                              label: l.create_post_win_count,
                              tokens: t,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildNumberField(
                        controller: _durationCtrl,
                        label: l.create_post_duration,
                        tokens: t,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _venueCtrl,
                        label: l.create_post_venue,
                        tokens: t,
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotTags(AppTokens t) {
    final hotTags = ref.watch(hotTagsProvider);
    return hotTags.when(
      data: (tags) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tags.map((tag) {
          final selected = _tags.contains(tag);
          return GestureDetector(
            onTap: () => _toggleHotTag(tag),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? t.accentSubtle : t.elev2,
                borderRadius: BorderRadius.circular(t.r1),
                border: selected
                    ? Border.all(color: t.accent, width: 1)
                    : null,
              ),
              child: Text(
                '#$tag',
                style: TextStyle(
                  fontSize: 13,
                  color: selected ? t.accent : t.inkSub,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        }).toList(),
      ),
      loading: () => const SizedBox(
        height: 32,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required AppTokens tokens,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.elev1,
        borderRadius: BorderRadius.circular(tokens.r2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: TextStyle(fontSize: 14, color: tokens.ink),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: TextStyle(fontSize: 13, color: tokens.inkDim),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required AppTokens tokens,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.elev1,
        borderRadius: BorderRadius.circular(tokens.r2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: 14, color: tokens.ink),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: TextStyle(fontSize: 13, color: tokens.inkDim),
        ),
      ),
    );
  }
}
