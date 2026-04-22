# 约球创建 — 活动标题 & 地图选点设计

日期：2026-04-22

## 概述

在约球创建流程中增加两项功能：

1. **活动标题**：选填文本框，未填时根据场地+时间自动生成
2. **地点选择**：全屏地图选点页面，支持拖动地图选点和搜索框 POI 搜索

## 一、活动标题字段

### 表单交互

- 位置：创建表单最顶部（在场地选择之前）
- 类型：选填文本框，`maxLength: 30`
- placeholder："给你的约球起个标题吧"

### 默认标题生成规则

用户未填写标题时，提交时自动生成 `"{场地名} {时间标签}"`。

时间标签逻辑：

| 条件 | 标签格式 | 示例 |
|------|----------|------|
| 当天 | 今天 HH:mm | 今天 19:30 |
| 明天 | 明天 HH:mm | 明天 19:30 |
| 本周内 | 周X HH:mm | 周五 19:30 |
| 超过本周 | M/d HH:mm | 4/25 19:30 |

### 数据存储

写入 `pickups.title` 字段（已存在，无需数据库迁移）。

## 二、地点选择器 — 创建表单侧

### 改造方案

将原来的纯文本"场地名称"和"详细地址"字段合并为**可点击的地点选择卡片**。

### 卡片外观

- 左侧：地图图标
- 右侧内容：
  - **未选择状态**：灰色提示文字"选择场地位置"，右侧箭头图标
  - **已选择状态**：上方主文字显示 POI 名称（如"莲花山足球场"），下方小字灰色显示详细地址（如"南宁市青秀区xxx路"），右侧清除按钮可重选
- 点击行为：跳转到 `LocationPickerScreen`

### 返回数据结构

```dart
class PickedLocation {
  final String name;     // POI 名称 → pickups.venue
  final String address;  // 详细地址 → pickups.address
  final double lat;      // 纬度 → pickups.lat（GCJ-02）
  final double lng;      // 经度 → pickups.lng（GCJ-02）
}
```

### 必填校验

地点为必填项，未选择时提交提示"请选择场地位置"。

## 三、全屏地图选点页面（LocationPickerScreen）

### 整体布局

从上到下三个区域：顶部搜索栏、中间地图区域、底部信息栏。

### 3.1 顶部搜索栏

- 左侧返回按钮（取消选择，返回创建页）
- 中间搜索输入框，placeholder："搜索地点"
- 输入时实时调用高德 POI 搜索 API，500ms 防抖
- 搜索结果以列表浮层覆盖在地图上方，每项显示 POI 名称 + 地址
- 点击某项：收起搜索列表，地图飞到该位置，底部显示该 POI 信息

### 3.2 中间地图区域

- 全屏高德地图
- 默认定位到用户当前位置（复用现有 Geolocator 逻辑，fallback 南宁 22.8170, 108.3665）
- 地图中心固定选点标记图标（pin），不随地图移动，始终在屏幕中央
- 用户拖动地图停止后，触发逆地理编码更新底部地址信息（500ms 防抖）
- 右下角"定位"按钮，点击回到用户当前位置

### 3.3 底部信息栏 + 确认按钮

- 显示当前选中点的 POI 名称（大字）和详细地址（小字灰色）
- "确认选点"按钮，点击后将 `PickedLocation` 返回给创建页面
- 初始状态显示用户当前位置的逆地理编码结果

## 四、高德 Web Service API 封装

新建 `lib/services/amap_search_service.dart`。

### 4.1 POI 关键字搜索

- 接口：`GET https://restapi.amap.com/v3/place/text`
- 参数：`key`（Env.amapKey 或单独的 Web Service Key）、`keywords`（用户输入）、`offset=20`
- 返回解析：提取 `pois` 数组中的 `name`、`address`、`location`（格式 "lng,lat"）
- 错误处理：网络异常返回空列表，不阻塞用户操作

### 4.2 逆地理编码

- 接口：`GET https://restapi.amap.com/v3/geocode/regeo`
- 参数：`key`、`location`（格式 "lng,lat"）
- 返回解析：
  - 详细地址：`regeocode.formatted_address`
  - POI 名称：优先 `regeocode.pois[0].name`，fallback `regeocode.addressComponent.neighborhood.name`

### 4.3 架构集成

- 用 Riverpod Provider 暴露
- HTTP 客户端使用 Dart `http` 包（项目已依赖）
- API Key 注意：当前 Key `320ae72b...` 是 Android/iOS 端 Key，Web Service API 可能需要单独申请。如已开通 Web Service 权限则可复用

## 五、数据流

```
LocationPickerScreen
  → 用户选点/搜索确认
  → Navigator.pop(PickedLocation)
  → CreatePickupScreen 接收数据
  → 填充到表单状态
  → 提交时写入 pickups 表（venue, address, lat, lng, title）
```

## 六、Web 端兼容

采用与现有地图相同的条件导入模式：

- **移动端**：完整高德地图 + 搜索 + 逆地理编码
- **Web 端 stub**：仅提供搜索框 + POI 列表选择（无地图），选中 POI 后直接返回其名称、地址、经纬度

## 七、坐标系

所有坐标统一使用 GCJ-02（高德地图原生坐标系），与现有数据库和导航逻辑一致。

## 八、文件改动清单

| 改动 | 文件 |
|------|------|
| 新增标题字段 + 地点选择卡片 | `lib/features/pickup/create_pickup_screen.dart` |
| 新增全屏地图选点页面 | `lib/features/pickup/location_picker_screen.dart`（含条件导入 mobile/stub） |
| 新增高德搜索服务 | `lib/services/amap_search_service.dart` |
| 路由注册 | `lib/router.dart`（或对应路由文件） |
| 默认标题生成 | `lib/features/pickup/create_pickup_screen.dart` 提交方法 |
| 数据库 | 无迁移，复用 pickups 表现有 title、venue、address、lat、lng 字段 |
