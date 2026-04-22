// real_map.dart — conditional-import entry.
// Web renders the SVG stub; iOS/Android use AMap (高德地图).
export 'real_map_stub.dart'
    if (dart.library.io) 'real_map_mobile.dart';
