// mini_map.dart — conditional-import entry for the read-only mini map
// used on pickup detail. Mobile uses AMapWidget; web uses an SVG placeholder.
export 'mini_map_stub.dart' if (dart.library.io) 'mini_map_mobile.dart';
