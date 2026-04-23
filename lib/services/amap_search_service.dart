import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import '../config/env.dart';

class PoiResult {
  final String name;
  final String address;
  final double lat;
  final double lng;

  const PoiResult({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });
}

class AmapSearchService {
  static const _base = 'https://restapi.amap.com/v3';

  Future<List<PoiResult>> searchPoi(String keywords, {String? city}) async {
    if (keywords.trim().isEmpty) return [];
    final uri = Uri.parse('$_base/place/text').replace(queryParameters: {
      'key': Env.amapWebKey,
      'keywords': keywords.trim(),
      'offset': '20',
      if (city != null && city.isNotEmpty) 'city': city,
      if (city != null && city.isNotEmpty) 'city_limit': 'true',
    });
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) {
        dev.log('AMap POI search HTTP ${resp.statusCode}', name: 'AmapSearch');
        return [];
      }
      final body = json.decode(resp.body) as Map<String, dynamic>;
      if (body['status'] != '1') {
        dev.log('AMap POI search failed: ${body['info']} (${body['infocode']})', name: 'AmapSearch');
        return [];
      }
      final pois = body['pois'] as List? ?? [];
      return pois.map((p) {
        final loc = (p['location'] as String? ?? '').split(',');
        final lng = double.tryParse(loc.isNotEmpty ? loc[0] : '') ?? 0;
        final lat = double.tryParse(loc.length > 1 ? loc[1] : '') ?? 0;
        return PoiResult(
          name: p['name'] as String? ?? '',
          address: p['address'] as String? ?? '',
          lat: lat,
          lng: lng,
        );
      }).where((p) => p.lat != 0 && p.lng != 0).toList();
    } catch (e) {
      dev.log('AMap POI search error: $e', name: 'AmapSearch');
      return [];
    }
  }

  Future<PoiResult?> reverseGeocode(double lat, double lng) async {
    final uri = Uri.parse('$_base/geocode/regeo').replace(queryParameters: {
      'key': Env.amapWebKey,
      'location': '${lng.toStringAsFixed(6)},${lat.toStringAsFixed(6)}',
      'extensions': 'all',
    });
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) {
        dev.log('AMap regeo HTTP ${resp.statusCode}', name: 'AmapSearch');
        return null;
      }
      final body = json.decode(resp.body) as Map<String, dynamic>;
      if (body['status'] != '1') {
        dev.log('AMap regeo failed: ${body['info']} (${body['infocode']})', name: 'AmapSearch');
        return null;
      }
      final regeo = body['regeocode'] as Map<String, dynamic>? ?? {};
      final formatted = regeo['formatted_address'] as String? ?? '';
      final pois = regeo['pois'] as List?;
      String name;
      if (pois != null && pois.isNotEmpty) {
        name = pois[0]['name'] as String? ?? '';
      } else {
        final comp = regeo['addressComponent'] as Map<String, dynamic>? ?? {};
        final nb = comp['neighborhood'] as Map<String, dynamic>? ?? {};
        name = nb['name'] as String? ?? '';
      }
      if (name.isEmpty) name = formatted;
      return PoiResult(name: name, address: formatted, lat: lat, lng: lng);
    } catch (e) {
      dev.log('AMap regeo error: $e', name: 'AmapSearch');
      return null;
    }
  }
}
