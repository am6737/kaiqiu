import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n_extension.dart';
import '../../utils/share_helper.dart';
import '../../utils/toast.dart';
import '../../models/comment.dart';
import '../../providers.dart';
import '../../services/supabase.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/avatar.dart';
import '../../widgets/network_avatar.dart';
import '../../widgets/interaction_btn.dart';
import '../../widgets/rich_input.dart';
import '../../widgets/typography.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const PostDetailScreen({super.key, required this.id});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = context.l10n;
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      showToast(context, l.comment_empty_toast, info: true);
      return;
    }
    if (!isSignedIn) {
      showToast(context, l.comment_login_required, info: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(commentsRepoProvider).add(
            targetType: 'post',
            targetId: widget.id,
            body: text,
          );
      _ctrl.clear();
      ref.invalidate(commentsProvider((type: 'post', id: widget.id)));
      ref.invalidate(postDetailProvider(widget.id));
    } catch (_) {
      if (mounted) {
        showToast(context, l.comment_send_failed, error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(postDetailProvider(widget.id));
    final commentsAsync = ref.watch(
      commentsProvider((type: 'post', id: widget.id)),
    );
    final l = context.l10n;
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: async.when(
        data: (data) => Column(
          children: [
            Expanded(
              child: _Body(data: data, commentsAsync: commentsAsync),
            ),
            RichInput(
              controller: _ctrl,
              onSend: _send,
              sending: _sending,
              hintText: l.comment_hint,
            ),
          ],
        ),
        loading: () => Center(
          child: CircularProgressIndicator(color: context.tokens.accent),
        ),
        error: (e, _) => _Error(
          error: e,
          onRetry: () => ref.invalidate(postDetailProvider(widget.id)),
          onBack: () => context.pop(),
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onBack;
  const _Error({
    required this.error,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: onBack,
                child: Icon(Icons.arrow_back_ios_new,
                    size: 20, color: context.tokens.ink),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 32, color: context.tokens.danger),
                  const SizedBox(height: 8),
                  Text('${l.error_load_failed}: $error',
                      style:
                          TextStyle(fontSize: 13, color: context.tokens.inkSub)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: onRetry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.tokens.elev3,
                        border: Border.all(color: context.tokens.line),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(l.common_retry,
                          style: TextStyle(
                              color: context.tokens.ink, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final Map<String, dynamic> data;
  final AsyncValue<List<Comment>> commentsAsync;
  const _Body({required this.data, required this.commentsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppL10n.of(context);
    final author = data['author'] as Map<String, dynamic>?;
    final authorName = (author?['name'] as String?) ?? '匿名';
    final authorAvatarUrl = author?['avatar_url'] as String?;
    final authorId = data['author_id'] as String?;
    final body = data['body'] as String? ?? '';
    final rawTags = data['tags'];
    final tags = rawTags is List ? rawTags.cast<String>() : <String>[];
    final likes = (data['likes'] as int?) ?? 0;
    final commentCount = (data['comments'] as int?) ?? 0;
    final shares = (data['shares'] as int?) ?? 0;
    final createdAt = DateTime.parse(data['created_at'] as String);
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(createdAt);
    final postId = data['id'] as String;

    final likedIds = ref.watch(likedPostIdsProvider).valueOrNull ?? {};
    final isLiked = likedIds.contains(postId);

    final matchCount = data['match_count'] as int?;
    final winCount = data['win_count'] as int?;
    final playDuration = data['play_duration'] as int?;
    final venue = data['venue'] as String?;
    final hasStats = matchCount != null;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          // App bar
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.elev2,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back_ios_new,
                        size: 16, color: t.ink),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.activity_detail_title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Author row
          GestureDetector(
            onTap: authorId != null
                ? () => context.push('/user/$authorId')
                : null,
            child: Row(
              children: [
                NetworkAvatar(authorName, url: authorAvatarUrl, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authorName,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: t.ink)),
                      const SizedBox(height: 2),
                      Text(
                        '$dateStr${venue != null ? ' · $venue' : ''}',
                        style: TextStyle(fontSize: 11, color: t.inkMute),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Body
          Text(
            body,
            style: TextStyle(fontSize: 15, color: t.ink, height: 1.8),
          ),

          // Activity stats
          if (hasStats) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: t.elev2,
                border: Border.all(color: t.line),
                borderRadius: BorderRadius.circular(t.r3),
              ),
              child: Row(
                children: [
                  _StatCell(
                    value: '$matchCount',
                    label: l.home_activity_matches,
                    accent: t.accent,
                  ),
                  _StatCell(
                    value: '${winCount ?? 0}W',
                    label: l.home_activity_record,
                  ),
                  _StatCell(
                    value: playDuration != null
                        ? '${(playDuration / 60).toStringAsFixed(1)}h'
                        : '—',
                    label: l.home_activity_duration,
                  ),
                ],
              ),
            ),
          ],

          // Tags
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: t.elev2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('#$tag',
                            style:
                                TextStyle(fontSize: 12, color: t.accent)),
                      ))
                  .toList(),
            ),
          ],

          const SizedBox(height: 20),
          Divider(color: t.line, height: 1),
          const SizedBox(height: 16),

          // Interaction stats — now interactive
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (!isSignedIn) {
                    showToast(context, l.like_login_required, info: true);
                    return;
                  }
                  ref.read(likesRepoProvider).toggle('post', postId).then((_) {
                    ref.invalidate(likedPostIdsProvider);
                    ref.invalidate(postDetailProvider(postId));
                  });
                },
                child: InteractionBtn(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    label: '$likes',
                    color: isLiked ? t.danger : t.inkSub),
              ),
              const SizedBox(width: 28),
              InteractionBtn(
                  icon: Icons.chat_bubble_outline,
                  label: '$commentCount',
                  color: t.inkSub),
              const SizedBox(width: 28),
              GestureDetector(
                onTap: () => sharePost(
                  authorName: authorName,
                  body: body,
                  tags: tags,
                ),
                child: InteractionBtn(
                    icon: Icons.share_outlined,
                    label: '$shares',
                    color: t.inkSub),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Divider(color: t.line, height: 1),
          const SizedBox(height: 20),

          // Comments section
          Label('${l.post_comments_title} · $commentCount'),
          const SizedBox(height: 14),

          // Real comments list
          ...commentsAsync.when(
            data: (list) => list.isEmpty
                ? [
                    Center(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 20),
                        child: Text(l.post_no_comments,
                            style: TextStyle(
                                fontSize: 13, color: t.inkDim)),
                      ),
                    ),
                  ]
                : list
                    .map<Widget>(
                        (c) => _CommentTile(comment: c))
                    .toList(),
            loading: () => [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: t.accent, strokeWidth: 2),
                  ),
                ),
              ),
            ],
            error: (_, _) => [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(l.error_load_failed,
                      style:
                          TextStyle(fontSize: 12, color: t.inkSub)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(comment.authorName, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(comment.authorName,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: t.ink)),
                    ),
                    Text(comment.displayTime,
                        style: TextStyle(fontSize: 10, color: t.inkMute)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.body,
                    style:
                        TextStyle(fontSize: 13, color: t.ink, height: 1.5)),
                const SizedBox(height: 6),
                if (comment.likes > 0)
                  InteractionBtn(
                      icon: Icons.favorite,
                      label: '${comment.likes}',
                      color: t.inkMute),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color? accent;
  const _StatCell({required this.value, required this.label, this.accent});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: t.fontMono,
                fontFamilyFallback: t.monoFallbacks,
                color: accent ?? t.ink,
              )),
          const SizedBox(height: 2),
          Label(label),
        ],
      ),
    );
  }
}
