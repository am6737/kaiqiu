# 约球地图气泡标签式标记

## 概述

将约球地图上的默认红色水滴 Marker 替换为气泡标签式自定义标记，显示球局价格（如 "¥30"），底部小三角指向地点，背景色按状态区分。提升地图视觉品质，让用户在地图上直接看到价格信息。

## 标签外观

```
  ┌──────┐
  │ ¥30  │   ← 圆角矩形，背景色按状态区分
  └──┬───┘
     ▼       ← 底部小三角指向地点
```

### 尺寸
- 高：28dp（不含三角）
- 宽：自适应文字 + 水平 padding 10dp
- 圆角：6dp
- 底部三角：6×6dp，居中对齐

### 文字
- 内容：`¥${feeYuan.toStringAsFixed(0)}`
- 字号：12sp
- 颜色：白色
- 字重：FontWeight.w700

### 选中态（activePin）
- 整体放大 1.2 倍
- 底部加阴影光晕（`BoxShadow(color: bgColor.withOpacity(0.4), blurRadius: 8)`）

### 颜色方案

| 状态 | 条件 | 背景色 | 含义 |
|------|------|--------|------|
| open | `displayNeed > 2` | `tokens.accent`（主题绿） | 招人中 |
| almost | `displayNeed > 0 && displayNeed <= 2` | `tokens.warn`（橙色） | 快满了 |
| full | `displayNeed == 0` | `tokens.inkMute`（灰色） | 已满 |

## 技术方案

使用 Widget-to-Bitmap 动态渲染：用 `CustomPainter` 绘制气泡标签，通过 `RepaintBoundary` + `RenderRepaintBoundary.toImage()` 转为 PNG 字节，再用 `BitmapDescriptor.fromBytes()` 作为 AMap Marker 图标。

### 渲染流程

1. 构建 `MarkerBubble` widget（`CustomPainter`）
2. 将 widget 放入 offscreen `RepaintBoundary`
3. 调用 `toImage()` → `toByteData(format: ImageByteFormat.png)` → `Uint8List`
4. 用 `BitmapDescriptor.fromBytes(bytes)` 创建图标
5. 缓存结果，相同参数不重复渲染

### 缓存策略

- 缓存 key：`"$text|$colorValue|$isActive"`
- 典型场景（20 个球局，3 种状态，5-6 种价格档）约 15 个缓存条目
- 使用 `Map<String, BitmapDescriptor>` 静态缓存，生命周期跟随 app

## 需要变更的文件

### 新建 `lib/features/pickup/map/marker_painter.dart`

1. `MarkerBubblePainter` — `CustomPainter` 子类：
   - 构造参数：`String text`、`Color bgColor`、`bool active`
   - `paint` 方法绘制：圆角矩形背景 → 底部三角 → 白色文字居中
   - 选中态：绘制外层阴影光晕
2. `Future<BitmapDescriptor> renderMarkerBitmap(String text, Color bgColor, bool active)` — 顶层异步函数：
   - 检查缓存，命中直接返回
   - 未命中：创建临时 offscreen widget → 渲染为 PNG → 转为 BitmapDescriptor → 存入缓存
3. 静态缓存 `Map<String, BitmapDescriptor> _cache`

### 修改 `lib/features/pickup/map/real_map_mobile.dart`

1. `_buildMarkers()` 改为返回同步的 `Set<Marker>`，但在 `initState` / `didUpdateWidget` 中预渲染所有 marker icon
2. 新增 `Map<String, BitmapDescriptor> _markerIcons` 本地状态
3. 新增 `_renderAllIcons()` 异步方法：遍历 pickups，调用 `renderMarkerBitmap()`，完成后 `setState`
4. `_buildMarkers()` 中使用 `_markerIcons[key]` 查找图标，未就绪时回退到默认 marker
5. 移除 `InfoWindow`（不再需要，点击 pin 现在会弹出浮动卡片）

### 修改 `lib/features/pickup/map/real_map_stub.dart`

1. 修改 `_Pin` widget 的 `build` 方法：
   - 移除当前的圆形 + SportIcon 布局
   - 替换为直接使用 `CustomPaint(painter: MarkerBubblePainter(...))` 渲染气泡标签
   - 保留 Positioned 定位逻辑和 GestureDetector

## 不需要的变更

- 不修改 `Pickup` 数据模型
- 不修改 `pickup_map_screen.dart`（调用侧不变，Marker 样式变化对其透明）
- 不修改路由或 Provider
- 不修改 `real_map.dart` 条件导出
