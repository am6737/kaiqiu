// danmaku_overlay.dart — B 站风格的直播弹幕叠层控件。
//
// 订阅一个 [Stream<DanmakuItem>],在固定轨道上从右向左匀速飘过文字。
// 与视频播放器叠加使用,外层需包 [IgnorePointer] 以免截获手势。

import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 一条弹幕的数据载体。
class DanmakuItem {
  final String user;
  final String text;
  final bool self;
  const DanmakuItem({
    required this.user,
    required this.text,
    required this.self,
  });
}
