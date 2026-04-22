// mini_map.dart — conditional-import entry for the read-only mini map
// used on pickup detail. Web renders the SVG stub; iOS/Android use AMap.
export 'mini_map_stub.dart'
    if (dart.library.io) 'mini_map_mobile.dart';
