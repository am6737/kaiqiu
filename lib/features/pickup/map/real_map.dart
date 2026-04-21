// real_map.dart — conditional-import entry.
// Mock-only for now: all platforms render the SVG stub so the UI is visible
// without a Google Maps key (and without depending on GMaps reachability in
// mainland China). Swap back to real_map_mobile.dart when a vendor is picked.
export 'real_map_stub.dart';
