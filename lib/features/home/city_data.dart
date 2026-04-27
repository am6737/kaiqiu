import 'dart:math';

class CityInfo {
  final String name;
  final String province;
  final String pinyin;
  final String region;
  final double lat;
  final double lng;

  const CityInfo({
    required this.name,
    required this.province,
    required this.pinyin,
    required this.region,
    required this.lat,
    required this.lng,
  });
}

const kRegionOrder = ['华北', '华东', '华南', '华中', '西南', '西北', '东北'];

const kHotCityNames = [
  '北京', '上海', '广州', '深圳', '杭州', '成都',
  '武汉', '西安', '南京', '重庆', '苏州', '天津',
];

const kAllCities = <CityInfo>[
  // ── 华北
  CityInfo(name: '北京', province: '直辖市', pinyin: 'beijing', region: '华北', lat: 39.9042, lng: 116.4074),
  CityInfo(name: '天津', province: '直辖市', pinyin: 'tianjin', region: '华北', lat: 39.0842, lng: 117.2010),
  CityInfo(name: '石家庄', province: '河北', pinyin: 'shijiazhuang', region: '华北', lat: 38.0428, lng: 114.5149),
  CityInfo(name: '太原', province: '山西', pinyin: 'taiyuan', region: '华北', lat: 37.8706, lng: 112.5489),
  CityInfo(name: '呼和浩特', province: '内蒙古', pinyin: 'huhehaote', region: '华北', lat: 40.8414, lng: 111.7500),
  // ── 华东
  CityInfo(name: '上海', province: '直辖市', pinyin: 'shanghai', region: '华东', lat: 31.2304, lng: 121.4737),
  CityInfo(name: '南京', province: '江苏', pinyin: 'nanjing', region: '华东', lat: 32.0603, lng: 118.7969),
  CityInfo(name: '苏州', province: '江苏', pinyin: 'suzhou', region: '华东', lat: 31.2990, lng: 120.5853),
  CityInfo(name: '杭州', province: '浙江', pinyin: 'hangzhou', region: '华东', lat: 30.2741, lng: 120.1551),
  CityInfo(name: '合肥', province: '安徽', pinyin: 'hefei', region: '华东', lat: 31.8206, lng: 117.2272),
  CityInfo(name: '福州', province: '福建', pinyin: 'fuzhou', region: '华东', lat: 26.0745, lng: 119.2965),
  CityInfo(name: '厦门', province: '福建', pinyin: 'xiamen', region: '华东', lat: 24.4798, lng: 118.0894),
  CityInfo(name: '济南', province: '山东', pinyin: 'jinan', region: '华东', lat: 36.6512, lng: 117.1201),
  CityInfo(name: '青岛', province: '山东', pinyin: 'qingdao', region: '华东', lat: 36.0671, lng: 120.3826),
  // ── 华南
  CityInfo(name: '广州', province: '广东', pinyin: 'guangzhou', region: '华南', lat: 23.1291, lng: 113.2644),
  CityInfo(name: '深圳', province: '广东', pinyin: 'shenzhen', region: '华南', lat: 22.5431, lng: 114.0579),
  CityInfo(name: '南宁', province: '广西', pinyin: 'nanning', region: '华南', lat: 22.8170, lng: 108.3665),
  CityInfo(name: '海口', province: '海南', pinyin: 'haikou', region: '华南', lat: 20.0440, lng: 110.1999),
  CityInfo(name: '三亚', province: '海南', pinyin: 'sanya', region: '华南', lat: 18.2528, lng: 109.5120),
  // ── 华中
  CityInfo(name: '武汉', province: '湖北', pinyin: 'wuhan', region: '华中', lat: 30.5928, lng: 114.3055),
  CityInfo(name: '长沙', province: '湖南', pinyin: 'changsha', region: '华中', lat: 28.2282, lng: 112.9388),
  CityInfo(name: '郑州', province: '河南', pinyin: 'zhengzhou', region: '华中', lat: 34.7466, lng: 113.6254),
  // ── 西南
  CityInfo(name: '重庆', province: '直辖市', pinyin: 'chongqing', region: '西南', lat: 29.4316, lng: 106.9123),
  CityInfo(name: '成都', province: '四川', pinyin: 'chengdu', region: '西南', lat: 30.5728, lng: 104.0668),
  CityInfo(name: '贵阳', province: '贵州', pinyin: 'guiyang', region: '西南', lat: 26.6470, lng: 106.6302),
  CityInfo(name: '昆明', province: '云南', pinyin: 'kunming', region: '西南', lat: 25.0389, lng: 102.7183),
  CityInfo(name: '拉萨', province: '西藏', pinyin: 'lasa', region: '西南', lat: 29.6500, lng: 91.1000),
  // ── 西北
  CityInfo(name: '西安', province: '陕西', pinyin: "xi'an", region: '西北', lat: 34.3416, lng: 108.9398),
  CityInfo(name: '兰州', province: '甘肃', pinyin: 'lanzhou', region: '西北', lat: 36.0611, lng: 103.8343),
  CityInfo(name: '西宁', province: '青海', pinyin: 'xining', region: '西北', lat: 36.6171, lng: 101.7782),
  CityInfo(name: '银川', province: '宁夏', pinyin: 'yinchuan', region: '西北', lat: 38.4872, lng: 106.2309),
  CityInfo(name: '乌鲁木齐', province: '新疆', pinyin: 'wulumuqi', region: '西北', lat: 43.8256, lng: 87.6168),
  // ── 东北
  CityInfo(name: '沈阳', province: '辽宁', pinyin: 'shenyang', region: '东北', lat: 41.8057, lng: 123.4315),
  CityInfo(name: '大连', province: '辽宁', pinyin: 'dalian', region: '东北', lat: 38.9140, lng: 121.6147),
  CityInfo(name: '长春', province: '吉林', pinyin: 'changchun', region: '东北', lat: 43.8171, lng: 125.3235),
  CityInfo(name: '哈尔滨', province: '黑龙江', pinyin: 'haerbin', region: '东北', lat: 45.8038, lng: 126.5350),
];

/// Group [kAllCities] by region, preserving [kRegionOrder].
Map<String, List<CityInfo>> get citiesByRegion {
  final map = <String, List<CityInfo>>{};
  for (final r in kRegionOrder) {
    map[r] = kAllCities.where((c) => c.region == r).toList();
  }
  return map;
}

/// Search cities by Chinese name or pinyin prefix.
List<CityInfo> searchCities(String query) {
  if (query.isEmpty) return [];
  final q = query.toLowerCase();
  return kAllCities.where((c) {
    return c.name.contains(query) || c.pinyin.toLowerCase().startsWith(q);
  }).toList();
}

/// Find the nearest supported city to the given coordinates.
/// Returns null if the nearest city is more than [maxDistanceKm] away.
CityInfo? findNearestCity(double lat, double lng, {double maxDistanceKm = 100}) {
  CityInfo? best;
  double bestDist = double.infinity;
  for (final city in kAllCities) {
    final d = _haversineKm(lat, lng, city.lat, city.lng);
    if (d < bestDist) {
      bestDist = d;
      best = city;
    }
  }
  if (bestDist > maxDistanceKm) return null;
  return best;
}

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _rad(double deg) => deg * pi / 180;
