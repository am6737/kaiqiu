class Teammate {
  final String id;
  final String name;
  final String? avatarUrl;
  final int matches;

  const Teammate({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.matches,
  });

  factory Teammate.fromMap(Map<String, dynamic> m) => Teammate(
    id: m['teammate_id'] as String,
    name: (m['teammate_name'] as String?) ?? '球友',
    avatarUrl: m['avatar_url'] as String?,
    matches: (m['matches'] as int?) ?? 0,
  );
}
