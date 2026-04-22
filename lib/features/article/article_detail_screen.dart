import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/article.dart';
import '../../repositories/likes_repository.dart';
import '../../utils/share_helper.dart';
import '../../models/comment.dart';
import '../../providers.dart';
import '../../services/supabase.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/avatar.dart';
import '../../widgets/rich_input.dart';
import '../../widgets/typography.dart';

class ArticleDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const ArticleDetailScreen({super.key, required this.id});

  @override
  ConsumerState<ArticleDetailScreen> createState() =>
      _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends ConsumerState<ArticleDetailScreen> {
  bool _viewCounted = false;
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _incrementViews();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _incrementViews() async {
    if (_viewCounted) return;
    _viewCounted = true;
    try {
      await ref.read(commentsRepoProvider).incrementArticleViews(widget.id);
    } catch (_) {}
  }

  Future<void> _send() async {
    final l = context.l10n;
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.comment_empty_toast)),
      );
      return;
    }
    if (!isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.comment_login_required)),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(commentsRepoProvider).add(
            targetType: 'article',
            targetId: widget.id,
            body: text,
          );
      _ctrl.clear();
      ref.invalidate(commentsProvider((type: 'article', id: widget.id)));
      ref.invalidate(articleDetailProvider(widget.id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.comment_send_failed)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(articleDetailProvider(widget.id));
    final commentsAsync = ref.watch(
      commentsProvider((type: 'article', id: widget.id)),
    );
    final l = context.l10n;
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: async.when(
        data: (article) => Column(
          children: [
            Expanded(
              child: _Body(
                article: article,
                commentsAsync: commentsAsync,
              ),
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
          onRetry: () => ref.invalidate(articleDetailProvider(widget.id)),
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
                          style:
                              TextStyle(color: context.tokens.ink, fontSize: 12)),
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
  final Article article;
  final AsyncValue<List<Comment>> commentsAsync;
  const _Body({required this.article, required this.commentsAsync});

  String _categoryLabel(BuildContext context, String cat) {
    final l = context.l10n;
    return switch (cat) {
      'match_report' => l.article_category_match_report,
      'preview' => l.article_category_preview,
      'tactics' => l.article_category_tactics,
      'interview' => l.article_category_interview,
      'analysis' => l.article_category_analysis,
      'fitness' => l.article_category_fitness,
      'gear' => l.article_category_gear,
      'pickup_guide' => l.article_category_pickup_guide,
      _ => cat,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = context.l10n;
    final likedIds = ref.watch(likedArticleIdsProvider).valueOrNull ?? {};
    final isLiked = likedIds.contains(article.id);
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(article.createdAt);
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: article.coverUrl != null ? 240 : 0,
          pinned: true,
          backgroundColor: t.bg,
          foregroundColor: t.ink,
          leading: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0x66000000),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  size: 16, color: Colors.white),
            ),
          ),
          flexibleSpace: article.coverUrl != null
              ? FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(article.coverUrl!, fit: BoxFit.cover),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.4, 1.0],
                            colors: [Colors.transparent, Color(0xCC000000)],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : null,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _categoryLabel(context, article.category),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: t.accent),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  article.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: t.ink,
                    height: 1.3,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 13, color: t.inkMute),
                    const SizedBox(width: 4),
                    Text(dateStr,
                        style: TextStyle(fontSize: 11, color: t.inkMute)),
                    const SizedBox(width: 14),
                    Icon(Icons.timer_outlined, size: 13, color: t.inkMute),
                    const SizedBox(width: 4),
                    Text('${article.readTimeMin}min',
                        style: TextStyle(fontSize: 11, color: t.inkMute)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('👁 ${article.viewCount}',
                        style: TextStyle(fontSize: 11, color: t.inkMute)),
                    const SizedBox(width: 14),
                    Text('💬 ${article.commentCount}',
                        style: TextStyle(fontSize: 11, color: t.inkMute)),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: () {
                        if (!isSignedIn) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l.like_login_required)),
                          );
                          return;
                        }
                        ref.read(likesRepoProvider).toggle('article', article.id).then((_) {
                          ref.invalidate(likedArticleIdsProvider);
                          ref.invalidate(articleDetailProvider(article.id));
                        });
                      },
                      child: Text(
                        '${isLiked ? "❤️" : "🤍"} ${article.likes}',
                        style: TextStyle(fontSize: 11, color: t.inkMute),
                      ),
                    ),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: () => shareArticle(
                        title: article.title,
                        category: _categoryLabel(context, article.category),
                        summary: article.summary,
                      ),
                      child: Text('↗️ ${l.common_share}',
                          style: TextStyle(fontSize: 11, color: t.inkMute)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(color: t.line, height: 1),
                const SizedBox(height: 20),
                if (article.summary != null &&
                    article.summary!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: t.elev2,
                      border:
                          Border(left: BorderSide(color: t.accent, width: 3)),
                      borderRadius: BorderRadius.circular(t.r2),
                    ),
                    child: Text(
                      article.summary!,
                      style: TextStyle(
                        fontSize: 14,
                        color: t.inkSub,
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (article.body != null && article.body!.isNotEmpty)
                  _ArticleBody(body: article.body!)
                else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Label(l.article_no_body),
                    ),
                  ),
                const SizedBox(height: 12),
                Divider(color: t.line, height: 1),
                const SizedBox(height: 20),
                Label('${l.post_comments_title} · ${article.commentCount}'),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        // Comments list
        commentsAsync.when(
          data: (list) => list.isEmpty
              ? SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Text(l.post_no_comments,
                          style: TextStyle(fontSize: 13, color: t.inkDim)),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) => _CommentTile(comment: list[i]),
                  ),
                ),
          loading: () => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: t.accent, strokeWidth: 2),
                ),
              ),
            ),
          ),
          error: (_, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(l.error_load_failed,
                    style: TextStyle(fontSize: 12, color: t.inkSub)),
              ),
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
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
                  Text('❤️ ${comment.likes}',
                      style: TextStyle(fontSize: 11, color: t.inkMute)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleBody extends StatelessWidget {
  final String body;
  const _ArticleBody({required this.body});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final paragraphs =
        body.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in paragraphs) ...[
          Text(
            p.trim(),
            style: TextStyle(fontSize: 15, color: t.ink, height: 1.8),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
