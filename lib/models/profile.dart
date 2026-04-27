// profile.dart — corresponds to Supabase profiles table
class Profile {
  final String id;
  final String name;
  final String? handle;
  final String? city;
  final String? district;
  final String? phone;
  final String? position;
  final int? height;
  final String? foot;
  final String? avatarUrl;
  final String? bannerUrl;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.name,
    this.handle,
    this.city,
    this.district,
    this.phone,
    this.position,
    this.height,
    this.foot,
    this.avatarUrl,
    this.bannerUrl,
    required this.createdAt,
  });

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
    id: m['id'] as String,
    name: m['name'] as String,
    handle: m['handle'] as String?,
    city: m['city'] as String?,
    district: m['district'] as String?,
    phone: m['phone'] as String?,
    position: m['position'] as String?,
    height: m['height'] as int?,
    foot: m['foot'] as String?,
    avatarUrl: m['avatar_url'] as String?,
    bannerUrl: m['banner_url'] as String?,
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'handle': handle,
    'city': city,
    'district': district,
    'phone': phone,
    'position': position,
    'height': height,
    'foot': foot,
    'avatar_url': avatarUrl,
    'banner_url': bannerUrl,
  };
}
