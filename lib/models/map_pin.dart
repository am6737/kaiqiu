// map_pin.dart — generic marker for the map (used by pickups + venues)
class MapPin {
  final String id;
  final double lat;
  final double lng;
  final String label;
  final String? sublabel;
  final MapPinType type;
  final MapPinState state;

  const MapPin({
    required this.id,
    required this.lat,
    required this.lng,
    required this.label,
    this.sublabel,
    this.type = MapPinType.pickup,
    this.state = MapPinState.open,
  });
}

enum MapPinType { pickup, venue }

enum MapPinState { open, almost, full }
