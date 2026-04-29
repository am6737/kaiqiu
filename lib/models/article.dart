class Article {
  final String id;
  final String? authorId;
  final String title;
  final String? summary;
  final String? body;
  final String? coverUrl;
  final String category;
  final int readTimeMin;
  final int viewCount;
  final int commentCount;
  final int likes;
  final String? city;
  final DateTime createdAt;

  const Article({
    required this.id,
    this.authorId,
    required this.title,
    this.summary,
    this.body,
    this.coverUrl,
    required this.category,
    this.readTimeMin = 5,
    this.viewCount = 0,
    this.commentCount = 0,
    this.likes = 0,
    this.city,
    required this.createdAt,
  });

  factory Article.fromMap(Map<String, dynamic> m) => Article(
        id: m['id'] as String,
        authorId: m['author_id'] as String?,
        title: m['title'] as String,
        summary: m['summary'] as String?,
        body: m['body'] as String?,
        coverUrl: m['cover_url'] as String?,
        category: m['category'] as String? ?? 'analysis',
        readTimeMin: m['read_time_min'] as int? ?? 5,
        viewCount: m['view_count'] as int? ?? 0,
        commentCount: m['comment_count'] as int? ?? 0,
        likes: m['likes'] as int? ?? 0,
        city: m['city'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
