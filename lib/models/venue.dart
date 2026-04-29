// venue.dart — 场馆 + 预约时段
enum VenueType { public, private_ }

VenueType _parseVenueType(String? s) => switch (s) {
  'public' => VenueType.public,
  _ => VenueType.private_,
};

enum VenueStatus { active, inactive, pending }

VenueStatus _parseVenueStatus(String? s) => switch (s) {
  'inactive' => VenueStatus.inactive,
  'pending' => VenueStatus.pending,
  _ => VenueStatus.active,
};

enum VenueFieldType { outdoor, indoor, semi }

VenueFieldType _parseFieldType(String? s) => switch (s) {
  'indoor' => VenueFieldType.indoor,
  'semi' => VenueFieldType.semi,
  _ => VenueFieldType.outdoor,
};

class Venue {
  final String id;
  final String ownerId;
  final VenueType venueType;
  final String? ownerName;
  final String name;
  final String? sportType;
  final String? description;
  final String address;
  final String? city;
  final double lat;
  final double lng;
  final String? phone;
  final String? coverUrl;
  final List<String> photos;
  final VenueFieldType fieldType;
  final int fieldCount;
  final int pricePerHourCents;
  final List<String> facilities;
  final String? openingHours;
  final VenueStatus status;
  final double? rating;
  final int reviewCount;
  final DateTime createdAt;

  const Venue({
    required this.id,
    required this.ownerId,
    this.venueType = VenueType.private_,
    this.ownerName,
    required this.name,
    this.sportType,
    this.description,
    required this.address,
    this.city,
    required this.lat,
    required this.lng,
    this.phone,
    this.coverUrl,
    this.photos = const [],
    this.fieldType = VenueFieldType.outdoor,
    this.fieldCount = 1,
    this.pricePerHourCents = 0,
    this.facilities = const [],
    this.openingHours,
    this.status = VenueStatus.active,
    this.rating,
    this.reviewCount = 0,
    required this.createdAt,
  });

  factory Venue.fromMap(Map<String, dynamic> m) => Venue(
    id: m['id'] as String,
    ownerId: m['owner_id'] as String,
    venueType: _parseVenueType(m['venue_type'] as String?),
    ownerName: m['owner_name'] as String?,
    name: m['name'] as String,
    sportType: m['sport_type'] as String?,
    description: m['description'] as String?,
    address: m['address'] as String,
    city: m['city'] as String?,
    lat: (m['lat'] as num).toDouble(),
    lng: (m['lng'] as num).toDouble(),
    phone: m['phone'] as String?,
    coverUrl: m['cover_url'] as String?,
    photos: (m['photos'] as List?)?.cast<String>() ?? const [],
    fieldType: _parseFieldType(m['field_type'] as String?),
    fieldCount: (m['field_count'] as int?) ?? 1,
    pricePerHourCents: (m['price_per_hour_cents'] as int?) ?? 0,
    facilities: (m['facilities'] as List?)?.cast<String>() ?? const [],
    openingHours: m['opening_hours'] as String?,
    status: _parseVenueStatus(m['status'] as String?),
    rating: (m['rating'] as num?)?.toDouble(),
    reviewCount: (m['review_count'] as int?) ?? 0,
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  bool get isPublic => venueType == VenueType.public;

  double get pricePerHourYuan => pricePerHourCents / 100;

  String get fieldTypeLabel => switch (fieldType) {
    VenueFieldType.outdoor => '室外',
    VenueFieldType.indoor => '室内',
    VenueFieldType.semi => '半室内',
  };

  String get sportTypeLabel => switch (sportType) {
    'football' => '足球',
    'basketball' => '篮球',
    'badminton' => '羽毛球',
    'tennis' => '网球',
    'volleyball' => '排球',
    'tabletennis' => '乒乓球',
    _ => '综合',
  };
}

enum BookingStatus { pending, confirmed, cancelled, completed }

BookingStatus _parseBookingStatus(String? s) => switch (s) {
  'confirmed' => BookingStatus.confirmed,
  'cancelled' => BookingStatus.cancelled,
  'completed' => BookingStatus.completed,
  _ => BookingStatus.pending,
};

class VenueBooking {
  final String id;
  final String venueId;
  final String? venueName;
  final String userId;
  final String? userName;
  final String? userPhone;
  final DateTime date;
  final String startTime;
  final String endTime;
  final int totalCents;
  final BookingStatus status;
  final String? note;
  final DateTime createdAt;

  const VenueBooking({
    required this.id,
    required this.venueId,
    this.venueName,
    required this.userId,
    this.userName,
    this.userPhone,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.totalCents = 0,
    this.status = BookingStatus.pending,
    this.note,
    required this.createdAt,
  });

  factory VenueBooking.fromMap(Map<String, dynamic> m) {
    String? venueName;
    final venuesData = m['venues'];
    if (venuesData is Map) {
      venueName = venuesData['name'] as String?;
    }
    return VenueBooking(
      id: m['id'] as String,
      venueId: m['venue_id'] as String,
      venueName: venueName ?? m['venue_name'] as String?,
      userId: m['user_id'] as String,
      userName: m['user_name'] as String?,
      userPhone: m['user_phone'] as String?,
      date: DateTime.parse(m['date'] as String),
      startTime: m['start_time'] as String,
      endTime: m['end_time'] as String,
      totalCents: (m['total_cents'] as int?) ?? 0,
      status: _parseBookingStatus(m['status'] as String?),
      note: m['note'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  double get totalYuan => totalCents / 100;

  String get statusLabel => switch (status) {
    BookingStatus.pending => '待确认',
    BookingStatus.confirmed => '已确认',
    BookingStatus.cancelled => '已取消',
    BookingStatus.completed => '已完成',
  };
}
