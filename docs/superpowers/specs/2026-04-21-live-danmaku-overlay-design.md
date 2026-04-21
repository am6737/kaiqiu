# 赛事直播弹幕叠层 设计文档

**Status:** Draft
**Date:** 2026-04-21
**Owner:** am6737

## 一、目标

在世界杯直播页 (`wc_live_screen.dart`) 的视频播放器之上,新增一层 **B 站风格的横向滚动弹幕**,在不改变现有下方气泡聊天列表的前提下,为直播氛围增加实时互动视觉效果。

## 二、约束与不做的事

**做:**

- 视频画面上叠加一层从右向左匀速飘过的文字弹幕
- 用户发送消息 / bot 生成的消息 **同时**进入弹幕层和下方聊天列表(单一数据源)
- 视频右上角提供弹幕开关,偏好持久化到 `LocalStore`
- 自己发送的弹幕视觉高亮(使用 `context.tokens.accent`)
- 全屏模式 (`_LiveFullscreenRoute`) 同样挂载弹幕层

**不做(YAGNI):**

- 不做弹幕速度 / 字号 / 透明度 / 密度等分级调节
- 不做颜色弹幕、顶部固定 / 底部固定等高级样式(固定滚动一种)
- 不做弹幕屏蔽词 / 正则过滤
- 不做历史弹幕回放(进入页面只接收新弹幕)
- 不做与服务端同步(沿用现有本地 bot + 自发模式)
- 不做弹幕点击、长按复制、举报等交互

## 三、架构总览

```
wc_live_screen.dart
  ├── StreamController<DanmakuItem> (state 持有,广播模式)
  │
  ├── bot timer (现有) ───┐
  └── _send() (现有) ─────┼──> _pushDanmu(item)
                          │       ├──> _danmuController.add(item)  → DanmakuOverlay
                          │       └──> _danmus.insert(0, item)     → 下方气泡列表
                          │
  Stack
    ├── LiveStreamPlayer   (底层,无改动)
    └── DanmakuOverlay     (顶层,IgnorePointer 不截获手势)
         ├── StreamSubscription: 接收新弹幕
         ├── List<_ActiveDanmu>: 当前正在飘的弹幕
         └── 多轨道调度 + AnimationController per 弹幕
```

**新增/修改文件清单:**

| 路径 | 类型 | 作用 |
|---|---|---|
| `lib/widgets/danmaku_overlay.dart` | 新增 | 独立可复用控件:订阅 Stream,渲染多轨道飘动文字 |
| `lib/features/events/wc_live_screen.dart` | 修改 | 引入 `StreamController`,视频层用 Stack 叠加 `DanmakuOverlay`,新增开关按钮 |
| `lib/services/local_storage.dart` | 修改 | 新增 `danmakuEnabled` 持久化字段 |
| `lib/l10n/*.arb` | 修改 | 新增弹幕开关的按钮标签(开 / 关) |

## 四、核心控件:`DanmakuOverlay`

### 4.1 接口

```dart
class DanmakuItem {
  final String user;
  final String text;
  final bool self;
  const DanmakuItem({required this.user, required this.text, required this.self});
}

class DanmakuOverlay extends StatefulWidget {
  final Stream<DanmakuItem> stream;
  final bool enabled;     // false 时丢弃进入的事件,已飘的正常飘完
  final int trackCount;   // 默认 4
  final Duration speed;   // 默认 8 秒
  const DanmakuOverlay({
    super.key,
    required this.stream,
    this.enabled = true,
    this.trackCount = 4,
    this.speed = const Duration(seconds: 8),
  });
}
```

### 4.2 轨道调度

- 固定轨道数 4 条,均匀分布在 Overlay 内的**有效弹幕区**(详见 4.3 的位置约束),避开顶部的分数牌 / 按钮和底部的 LIVE pill / 观众数 overlay。
- 每条弹幕入场时选择"**当前轨道上最后一条弹幕的右边界离屏幕右边最远**"的轨道(即最空闲的轨道)。若所有轨道的最后一条弹幕右边界仍在屏幕内(会追尾),则直接丢弃该弹幕——保证不会叠字。
- 每条弹幕自带一个 `AnimationController`,从 `offset: screenWidth`(右边界外刚好出现)动画到 `offset: -textWidth`(左边界外完全消失),`Curves.linear`,时长 `widget.speed`。
- 动画完成后从活跃列表移除,`controller.dispose()`。

### 4.3 视觉规范与位置约束

- 文字:14sp,`FontWeight.w600`,白色,带 2px 的半透明黑色 `Shadow` 描边(保证各种画面底色可读)。
- `self == true` 的弹幕:文字颜色改为 `context.tokens.accent`,文字背景加胶囊底(`color: context.tokens.accentSubtle`,`border: 1px context.tokens.accent`,`BorderRadius.circular(999)`,水平内边距 8px),便于一眼识别。
- 轨道高度:28px,实际文字居中渲染。
- **有效弹幕区**:视频容器内的中段,顶部留 `80px` 避开现有 `topLeft` / `topRight` 按钮(top: 40)和 `scoreOverlay`(top: 44);底部留 `40px` 避开 LIVE pill / 观众数 overlay(bottom: 10)。4 条轨道均匀分布在这个中段内。
- 在 240px 高的竖屏视频下,有效区 = `[80, 200]` 共 120px,轨道 y 中心分别为 `80 + (28/2) + i × ((120 - 28) / 3)`,i ∈ {0,1,2,3}。
- 全屏下高度改变,用 `LayoutBuilder` 获取当前容器高度动态计算,逻辑相同。

### 4.4 开关语义

- `enabled == false`:`StreamSubscription` 仍然订阅,但入口回调直接 return;**不暂停已在飘的弹幕**,让它们自然飘完。
- `enabled` 从 false → true:从下一个新事件开始接收,不回放历史。
- Widget dispose:取消订阅,遍历活跃弹幕逐个 `controller.dispose()`。

## 五、`wc_live_screen.dart` 改动

### 5.1 新增 state

```dart
late final StreamController<DanmakuItem> _danmuController;
bool _danmakuOn = LocalStore.danmakuEnabled; // 读取持久化
```

`initState` 里 `_danmuController = StreamController<DanmakuItem>.broadcast();`,`dispose` 里 `close()`。

### 5.2 抽出 `_pushDanmu`

把现有 `_send()` 和 bot timer 里往 `_danmus` 写入的两处,合并到一个私有方法:

```dart
void _pushDanmu(_Danmu d) {
  setState(() {
    _danmus.insert(0, d);
    if (_danmus.length > 40) _danmus.removeLast();
  });
  _danmuController.add(DanmakuItem(user: d.user, text: d.text, self: d.self));
}
```

现有两处调用点改为 `_pushDanmu(...)`。

### 5.3 视频区域改为 Stack

```dart
SizedBox(
  height: 240,
  child: Stack(
    children: [
      LiveStreamPlayer(... /* 原参数不变 */),
      Positioned.fill(
        child: IgnorePointer(
          child: DanmakuOverlay(
            stream: _danmuController.stream,
            enabled: _danmakuOn,
          ),
        ),
      ),
    ],
  ),
)
```

`IgnorePointer` 保证弹幕层不抢 tap-to-toggle-controls 手势。

### 5.4 开关按钮

`LiveStreamPlayer.topRight` 目前是 `_ReminderButton`。改为:

```dart
topRight: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    _DanmakuToggleButton(
      on: _danmakuOn,
      onTap: () {
        setState(() => _danmakuOn = !_danmakuOn);
        LocalStore.setDanmakuEnabled(_danmakuOn);
      },
    ),
    const SizedBox(width: 8),
    _ReminderButton(... 原参数),
  ],
),
```

`_DanmakuToggleButton` 与 `_ReminderButton` 风格一致:半透明黑色胶囊,图标 + 文字,开启态图标上色 `accent`。图标使用 `Icons.subtitles` 或 `Icons.chat_bubble_outline` 斜线变体,文案取 l10n key `wc_btn_danmaku_on` / `wc_btn_danmaku_off`。

### 5.5 全屏支持

`_LiveFullscreenRoute` 改造:新增构造参数 `Stream<DanmakuItem> danmakuStream` + `bool danmakuEnabled`,在视频上同样叠一层 `DanmakuOverlay`。`_enterFullscreen` 传入 `_danmuController.stream` 和 `_danmakuOn`。

由于是 `.broadcast()` stream,两处同时订阅互不干扰。全屏路由打开期间,底层竖屏的 `DanmakuOverlay` 被路由遮挡但仍在订阅 + 动画——每条弹幕一个 `AnimationController` 的轻微 vsync 消耗在可接受范围内(同屏 ≤4 条弹幕),**不做特殊暂停处理**,实现简单优先。

## 六、本地存储

`lib/services/local_storage.dart` 新增:

```dart
const _kDanmakuEnabled = 'danmaku_enabled';

// in class LocalStore:
static bool get danmakuEnabled => _prefs.getBool(_kDanmakuEnabled) ?? true;
static Future<void> setDanmakuEnabled(bool v) async {
  await _prefs.setBool(_kDanmakuEnabled, v);
  localStoreNotifier.bump();
}
```

默认 `true`(默认开启)。

## 七、国际化

`lib/l10n/app_zh.arb` / `app_en.arb` / 其他已有语言新增:

| key | zh | en |
|---|---|---|
| `wc_btn_danmaku_on` | 弹幕 开 | Danmaku On |
| `wc_btn_danmaku_off` | 弹幕 关 | Danmaku Off |

## 八、边界与错误处理

| 场景 | 处理 |
|---|---|
| 所有 4 条轨道当前都会追尾 | 丢弃新弹幕(不排队,避免堆积爆发) |
| 弹幕极长(如用户输入 200 字) | 不截断,让它按 `textWidth` 飞完,但 `trackCount` 调度会让其他弹幕绕开 |
| 视频区域 resize(旋转、全屏) | 活跃的 `AnimationController` 用 `LayoutBuilder` 感知宽度变化;最简方案:resize 发生时,清空所有活跃弹幕重新开始(避免位置计算混乱) |
| `_danmuController` 在没有订阅者时 add | 用 `.broadcast()`,事件直接丢弃,无压力 |
| bot 爆发(现有代码每 5s 有 1/3 概率产生消息) | 天然限流,无需额外处理 |

## 九、测试

- **控件单元测试**:`test/widgets/danmaku_overlay_test.dart`
  - 入口 stream add 两条弹幕,pump 500ms 后 find `Text` 能看到两条
  - `enabled: false` 时 add 弹幕,pump 后 find `Text` 找不到
  - 4 条轨道满载时第 5 条被丢弃
- **页面集成测试**:`test/features/events/wc_live_screen_test.dart`
  - 点开关按钮,再发一条消息,弹幕层不出现文字
  - 发一条消息,下方聊天列表和弹幕层都能找到该文本

## 十、实施顺序

1. `local_storage.dart` 加 `danmakuEnabled` 持久化
2. 新增 `danmaku_overlay.dart`(含单元测试)
3. `wc_live_screen.dart` 引入 `StreamController`、改 Stack 叠层、加开关按钮
4. `_LiveFullscreenRoute` 传入 stream 并挂载 Overlay
5. l10n 补齐开关文案
6. 端到端手动验证:portrait + 全屏两种状态、开关切换、自发 + bot 弹幕混合
