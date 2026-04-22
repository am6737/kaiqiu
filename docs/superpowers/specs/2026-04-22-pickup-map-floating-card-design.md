# 约球地图浮动球局卡片

## 概述

在约球页面（`PickupMapScreen`）地图上点击标记（pin）后，在屏幕底部弹出一张浮动小卡片，显示球局简要信息。点击卡片进入球局详情页。替代当前"点击 pin → 展开底部列表"的交互，提供更直接的预览体验。

## 交互流程

### 当前行为
1. 点击 pin → 底部列表展开到 55%
2. 用户在列表中找到对应球局 → 点击跳转详情

### 新行为
1. 点击 pin → 底部列表收起到最小高度 → 页面底部浮现球局小卡片（滑入动画）
2. 点击卡片 → `context.push('/pickup/$id')` 进入详情页
3. 点击地图空白处 / 拖动地图 → 卡片消失（滑出动画），列表恢复原始高度
4. 点击另一个 pin → 卡片内容切换为新球局（淡入切换）
5. 上拉底部列表 → 监听 `_sheetCtrl` 的 size 变化，当 size > minChildSize 时自动清除 `_activePin`，卡片消失

## 卡片设计

### 布局

卡片固定在屏幕底部，距离底部安全区 + 16dp，左右各 16dp 边距。

```
┌─────────────────────────────────────┐
│  ┌──────┐  场地名称          还差3人 │
│  │ 封面 │  今晚 19:30 · 5v5        │
│  │  图  │  ¥30 · 2.1km        →    │
│  └──────┘                           │
└─────────────────────────────────────┘
```

- **左侧：** 56×56 圆角封面图（`venuePhotoUrl`），无图时显示 `SportIcon` 占位
- **中间：** 场地名（`venue`，单行截断）、时间（`displayTime`）+ 阵型（`formation`）、费用（`feeYuan`）+ 距离
- **右侧：** 状态标签 + 右箭头图标（`Icons.chevron_right`）

### 样式
- 背景：`tokens.elev2`
- 圆角：`tokens.r3`
- 阴影：`BoxShadow(color: black12, blurRadius: 12, offset: (0, -2))`
- 封面图圆角：8dp

### 状态标签
- 还差 >2 人：绿色背景 `"有位"`
- 还差 1-2 人：橙色背景 `"快满了"`
- 已满：灰色背景 `"已满"`

复用 `PickupFeedCard` 中已有的 `_urgencyBadge` 逻辑。

## 动画

- **卡片出现：** `AnimatedSlide` offset 从 (0, 1) → (0, 0) + `AnimatedOpacity` 0 → 1，300ms `Curves.easeOut`
- **卡片消失：** 反向动画，设置 `_activePin = null`
- **切换球局：** `AnimatedSwitcher` 包裹卡片内容，200ms crossfade
- **底部列表：** `_sheetCtrl.animateTo(minChildSize)` 收起 / `_sheetCtrl.animateTo(0.55)` 恢复

## 状态管理

全部在 `_PickupMapScreenState` 本地 state 中管理，不新增 Provider：

- `_activePin`（已有）：选中的球局 ID，非空时显示浮动卡片
- 从 `pickups` 列表中通过 `_activePin` 查找对应 `Pickup` 对象
- `_distanceTo()` 方法（已有）计算距离

## 需要修改的文件

### `lib/features/pickup/pickup_map_screen.dart`

1. 新增 `_PickupFloatingCard` 私有 widget：
   - 接收 `Pickup` 对象、距离字符串、`onTap` 回调
   - 渲染上述卡片布局
2. 修改 `_buildMap` 方法的 `Stack`：
   - 在 `DraggableScrollableSheet` 之上添加浮动卡片层
   - 用 `AnimatedSlide` + `AnimatedOpacity` 控制显隐
3. 修改 `onPinTap` 回调：
   - 设置 `_activePin`
   - 调用 `_sheetCtrl.animateTo(minChildSize)` 收起列表
4. 新增 `_dismissCard()` 方法：
   - 清空 `_activePin`
   - 调用 `_sheetCtrl.animateTo(0.55)` 恢复列表
5. 传递新的 `onMapTap` 回调给 `RealPickupMap`

### `lib/features/pickup/map/real_map_mobile.dart`

1. 新增 `VoidCallback? onMapTap` 参数
2. 在 `AMapWidget` 中连接 `onTap: (LatLng pos) => widget.onMapTap?.call()`

### `lib/features/pickup/map/real_map_stub.dart`

1. 新增 `VoidCallback? onMapTap` 参数
2. 在背景 `Container` 上包裹 `GestureDetector`，`onTap` 触发回调

## 不需要的变更

- 不新增文件
- 不新增 Riverpod Provider
- 不修改路由
- 不修改 `Pickup` 数据模型
- 不修改 `real_map.dart` 条件导出（参数签名通过命名参数兼容）
