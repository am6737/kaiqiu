// profile.dart — corresponds to Supabase profiles table
class Profile {
  final String id;
  final String name;
  final String? handle;
  final String? city;
  final String? district;
  final String? position;
  final int? height;
  final String? foot;
  final int credit;
  final String? avatarUrl;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.name,
    this.handle,
    this.city,
    this.district,
    this.position,
    this.height,
    this.foot,
    this.credit = 60,
    this.avatarUrl,
    required this.createdAt,
  });

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        name: m['name'] as String,
        handle: m['handle'] as String?,
        city: m['city'] as String?,
        district: m['district'] as String?,
        position: m['position'] as String?,
        height: m['height'] as int?,
        foot: m['foot'] as String?,
        credit: (m['credit'] as int?) ?? 60,
        avatarUrl: m['avatar_url'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'handle': handle,
        'city': city,
        'district': district,
        'position': position,
        'height': height,
        'foot': foot,
        'credit': credit,
        'avatar_url': avatarUrl,
      };
}
