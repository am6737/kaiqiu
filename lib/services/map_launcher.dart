// map_launcher.dart — open external map apps for driving directions.
//
// Detects installed map apps (Amap / Baidu) via `canLaunchUrl` and shows a
// bottom sheet letting the user pick one. A system-default `geo:` / Apple
// Maps fallback is always offered so the action never dead-ends.
//
// Coordinates are assumed to be GCJ-02 because they come from Amap; Amap
// and Baidu URL schemes accept GCJ-02 directly (for Baidu we pass
// `coord_type=gcj02`). Apple Maps over `https://maps.apple.com` uses WGS-84
// — the offset is a few dozen meters inside mainland China, acceptable for
// driving-level navigation and only hit when neither Amap nor Baidu is
// installed.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n_extension.dart';
import '../theme/tokens.dart';
import '../theme/app_tokens.dart';
import '../utils/toast.dart';

enum _MapApp { amap, baidu, system }

class _MapOption {
  final _MapApp app;
  final String label;
  final IconData icon;
  final Uri uri;
  const _MapOption(this.app, this.label, this.icon, this.uri);
}

class MapLauncher {
  MapLauncher._();

  /// Opens an external map app with driving directions to `(lat, lng)`.
  /// Shows a bottom-sheet chooser with the apps that are actually installed;
  /// always includes a system-default fallback.
  static Future<void> openNavigation({
    required BuildContext context,
    required double lat,
    required double lng,
    required String name,
  }) async {
    final l = context.l10n;
    final encodedName = Uri.encodeComponent(name);

    final amapUri = _amapUri(lat: lat, lng: lng, name: encodedName);
    final baiduUri = Uri.parse(
      'baidumap://map/direction'
      '?destination=latlng:$lat,$lng|name:$encodedName'
      '&mode=driving&coord_type=gcj02',
    );
    final systemUri = _systemUri(lat: lat, lng: lng, name: encodedName);

    final options = <_MapOption>[];

    if (await _probe(amapUri)) {
      options.add(
        _MapOption(_MapApp.amap, l.pickup_detail_nav_amap, Icons.map, amapUri),
      );
    }
    if (await _probe(baiduUri)) {
      options.add(
        _MapOption(
          _MapApp.baidu,
          l.pickup_detail_nav_baidu,
          Icons.map_outlined,
          baiduUri,
        ),
      );
    }
    // System fallback — always present. On web this is the only option.
    options.add(
      _MapOption(
        _MapApp.system,
        l.pickup_detail_nav_system,
        Icons.near_me,
        systemUri,
      ),
    );

    if (!context.mounted) return;

    // Single option → launch directly, skip the sheet.
    if (options.length == 1) {
      await _launch(context, options.single.uri);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.tokens.elev1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: T.inkMute,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l.pickup_detail_nav_chooser_title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: T.ink,
                ),
              ),
              const SizedBox(height: 12),
              for (final opt in options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(opt.icon, color: T.live),
                  title: Text(
                    opt.label,
                    style: const TextStyle(
                      color: T.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _launch(context, opt.uri);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Uri _amapUri({
    required double lat,
    required double lng,
    required String name,
  }) {
    if (!kIsWeb && Platform.isIOS) {
      return Uri.parse(
        'iosamap://path'
        '?sourceApplication=kaiqiu'
        '&dlat=$lat&dlon=$lng&dname=$name'
        '&dev=0&t=0',
      );
    }
    return Uri.parse(
      'androidamap://route/plan/'
      '?dlat=$lat&dlon=$lng&dname=$name&dev=0&t=0',
    );
  }

  static Uri _systemUri({
    required double lat,
    required double lng,
    required String name,
  }) {
    if (!kIsWeb && Platform.isIOS) {
      return Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&q=$name');
    }
    return Uri.parse('geo:$lat,$lng?q=$lat,$lng($name)');
  }

  static Future<bool> _probe(Uri uri) async {
    if (kIsWeb) return false;
    try {
      return await canLaunchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  static Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        showToast(context, context.l10n.pickup_detail_nav_none, error: true);
      }
    } catch (_) {
      if (context.mounted) {
        showToast(context, context.l10n.pickup_detail_nav_none, error: true);
      }
    }
  }
}
