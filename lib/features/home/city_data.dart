import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

class Division {
  final String name;
  final String pinyin;
  final double? lat;
  final double? lng;
  final List<Division> children;

  const Division({
    required this.name,
    required this.pinyin,
    this.lat,
    this.lng,
    this.children = const [],
  });

  factory Division.fromJson(Map<String, dynamic> j) => Division(
        name: j['name'] as String,
        pinyin: (j['pinyin'] as String?) ?? '',
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        children: j['children'] != null
            ? (j['children'] as List)
                .map((c) => Division.fromJson(c as Map<String, dynamic>))
                .toList()
            : [],
      );
}

const kHotCityNames = [
  '北京市',
  '上海市',
  '广州市',
  '深圳市',
  '杭州市',
  '成都市',
  '武汉市',
  '西安市',
  '南京市',
  '重庆市',
  '苏州市',
  '天津市',
];

List<Division>? _cached;

Future<List<Division>> loadDivisions() async {
  if (_cached != null) return _cached!;
  final raw = await rootBundle.loadString('assets/china_divisions.json');
  final list = jsonDecode(raw) as List;
  _cached =
      list.map((e) => Division.fromJson(e as Map<String, dynamic>)).toList();
  return _cached!;
}

class SearchResult {
  final String path;
  final List<String> parts;
  SearchResult(this.parts) : path = parts.join('/');

  String get display => parts.join(' > ');
}

List<SearchResult> searchDivisions(List<Division> provinces, String query) {
  if (query.isEmpty) return [];
  final q = query.toLowerCase();
  final results = <SearchResult>[];

  for (final prov in provinces) {
    if (prov.name.contains(query) || prov.pinyin.startsWith(q)) {
      results.add(SearchResult([prov.name]));
    }
    for (final city in prov.children) {
      if (city.name.contains(query) || city.pinyin.startsWith(q)) {
        results.add(SearchResult([prov.name, city.name]));
      }
      for (final dist in city.children) {
        if (dist.name.contains(query) || dist.pinyin.startsWith(q)) {
          results.add(SearchResult([prov.name, city.name, dist.name]));
        }
      }
    }
  }
  return results;
}

String? findNearestCityPath(
    List<Division> provinces, double lat, double lng) {
  String? bestPath;
  double bestDist = double.infinity;

  for (final prov in provinces) {
    for (final city in prov.children) {
      if (city.lat == null || city.lng == null) continue;
      final d = _haversineKm(lat, lng, city.lat!, city.lng!);
      if (d < bestDist) {
        bestDist = d;
        bestPath = '${prov.name}/${city.name}';
      }
    }
  }
  if (bestDist > 100) return null;
  return bestPath;
}

Map<String, List<Division>> groupByPinyinInitial(List<Division> items) {
  final map = <String, List<Division>>{};
  for (final item in items) {
    final letter =
        item.pinyin.isNotEmpty ? item.pinyin[0].toUpperCase() : '#';
    map.putIfAbsent(letter, () => []).add(item);
  }
  return Map.fromEntries(
    map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
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
