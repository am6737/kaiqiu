// real_map.dart — conditional-import entry.
// Web loads the SVG fallback; mobile loads amap_flutter_map.
export 'real_map_stub.dart' if (dart.library.io) 'real_map_mobile.dart';
