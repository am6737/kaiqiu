// pickup.dart — 约球 + slots
enum PickupStatus { open, almost, full, done }

PickupStatus _parseStatus(String? s) => switch (s) {
  'almost' => PickupStatus.almost,
  'full' => PickupStatus.full,
  'done' => PickupStatus.done,
  _ => PickupStatus.open,
};

class Pickup {
  final String id;
  final String? hostId; // nullable: seed data has no host yet
  final String? hostName; // display-only fallback when hostId is null
  final String venue;
  final String? address;
  final double? lat;
  final double? lng;
  final DateTime startAt;
  final String? timeLabel; // display string like "今晚 19:30"
  final int durationMin;
  final int total;
  final int? need; // display-only mock "缺 N 人"
  final String? level;
  final int feeCents;
  final String formation;
  final String? fieldType;
  final PickupStatus status;
  final DateTime createdAt;

  const Pickup({
    required this.id,
    this.hostId,
    this.hostName,
    required this.venue,
    this.address,
    this.lat,
    this.lng,
    required this.startAt,
    this.timeLabel,
    this.durationMin = 120,
    required this.total,
    this.need,
    this.level,
    this.feeCents = 0,
    this.formation = '4-3-3',
    this.fieldType,
    this.status = PickupStatus.open,
    required this.createdAt,
  });

  factory Pickup.fromMap(Map<String, dynamic> m) => Pickup(
    id: m['id'] as String,
    hostId: m['host_id'] as String?,
    hostName: m['host_name'] as String?,
    venue: m['venue'] as String,
    address: m['address'] as String?,
    lat: (m['lat'] as num?)?.toDouble(),
    lng: (m['lng'] as num?)?.toDouble(),
    startAt: DateTime.parse(m['start_at'] as String),
    timeLabel: m['time_label'] as String?,
    durationMin: (m['duration_min'] as int?) ?? 120,
    total: m['total'] as int,
    need: m['need'] as int?,
    level: m['level'] as String?,
    feeCents: (m['fee_cents'] as int?) ?? 0,
    formation: (m['formation'] as String?) ?? '4-3-3',
    fieldType: m['field_type'] as String?,
    status: _parseStatus(m['status'] as String?),
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  double get feeYuan => feeCents / 100;
  String get displayHost => hostName ?? '—';
  String get displayTime => timeLabel ?? '';
  int get displayNeed => need ?? 0;
}

class PickupSlot {
  final String id;
  final String pickupId;
  final String? userId;
  final String? displayName;
  final String position;
  final int x;
  final int y;

  const PickupSlot({
    required this.id,
    required this.pickupId,
    this.userId,
    this.displayName,
    required this.position,
    required this.x,
    required this.y,
  });

  factory PickupSlot.fromMap(Map<String, dynamic> m) => PickupSlot(
    id: m['id'] as String,
    pickupId: m['pickup_id'] as String,
    userId: m['user_id'] as String?,
    displayName: m['display_name'] as String?,
    position: m['position'] as String,
    x: m['x'] as int,
    y: m['y'] as int,
  );

  /// A slot is "filled" when someone occupies it (real user or demo name).
  bool get filled => userId != null || displayName != null;

  /// First character to draw inside the dot.
  /// Avoids grapheme-cluster edge cases by just slicing the first "rune"
  /// via runes — good enough for CJK single-character names.
  String initial(String? currentUserId) {
    if (displayName != null && displayName!.isNotEmpty) {
      return String.fromCharCode(displayName!.runes.first);
    }
    if (userId == currentUserId) return '你';
    if (userId != null) return userId!.substring(0, 1).toUpperCase();
    return '+';
  }
}
