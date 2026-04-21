// mini_map.dart — conditional-import entry for the read-only mini map
// used on pickup detail. Mock-only for now: all platforms render the SVG
// placeholder so the UI is visible without a Google Maps key. Swap back to
// mini_map_mobile.dart when a real map vendor is picked.
export 'mini_map_stub.dart';
