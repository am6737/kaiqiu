# 场馆营业时间选择器设计

## 概述

将场馆发布页面的营业时间从手动文本输入改为底部弹出的滚轮选择器（CupertinoPicker 风格），提升输入体验并防止格式错误。

## 当前状态

- `create_venue_screen.dart` 第30行：`TextEditingController(text: '08:00-22:00')`
- 第355-359行：普通 `_TextField` 组件，用户手动输入
- 数据库字段：`opening_hours text`（`venues` 表）
- 数据格式：`"HH:MM-HH:MM"` 字符串

## 设计方案

### 交互流程

1. 表单中营业时间行显示为可点击的展示区域（非输入框），显示当前选中的时间段
2. 点击后从底部弹出 BottomSheet，包含双列滚轮选择器
3. 用户滚动选择开始时间和结束时间
4. 点击"确定"回填到表单，点击"取消"或下滑关闭不做变更

### 表单触发行

替换原来的 `_TextField`，改为一个可点击的容器：
- 上方小字标签"营业时间"
- 下方大字显示当前时间段，如"08:00 — 22:00"
- 右侧箭头图标提示可点击
- 样式与现有 `_TextField` 的填充背景风格一致（`filled: true`，圆角）

### BottomSheet 滚轮选择器

结构从上到下：
1. **拖动条** — 顶部居中的小灰条，提示可下滑关闭
2. **标题栏** — 左侧"取消"、中间"营业时间"、右侧"确定"
3. **实时预览** — 大号字体显示当前选中的 `开始时间 — 结束时间`，下方小字显示计算出的总时长（如"共14小时"）
4. **双列滚轮** — 左列"开始时间"、右列"结束时间"，使用 `CupertinoPicker`

### 滚轮参数

| 参数 | 值 |
|------|-----|
| 时间范围 | 00:00 — 24:00 |
| 步进 | 30 分钟 |
| 可选项 | 00:00, 00:30, 01:00, ... 23:30, 24:00（共49项） |
| 默认开始 | 08:00 |
| 默认结束 | 22:00 |
| 滚轮高度 | 约 200px，显示 5 项，选中项居中高亮 |

### 校验规则

- 结束时间必须严格大于开始时间
- 不满足时"确定"按钮置灰（禁用态），同时预览区域文字变灰提示
- 无需 toast 或错误提示，视觉反馈足够

### 数据兼容

- 输出格式保持 `"HH:MM-HH:MM"` 字符串，与现有 `opening_hours` 字段完全兼容
- 数据库、模型类（`Venue.openingHours`）、详情页展示均无需改动
- 已发布的场馆数据（如 seed 中的 `"08:00-22:00"`）自然兼容

## 实现方式

- 使用 Flutter 内置 `CupertinoPicker`，无需引入第三方包
- 新增一个私有组件 `_OpeningHoursPickerSheet`，放在 `create_venue_screen.dart` 内
- 通过 `showModalBottomSheet` 弹出
- 返回值为 `(String startTime, String endTime)` 的 Record

## 影响范围

| 文件 | 变更 |
|------|------|
| `lib/features/venue/create_venue_screen.dart` | 删除 `_openingHours` TextEditingController；替换营业时间行为可点击展示区域；新增 `_OpeningHoursPickerSheet` 组件 |
| 数据库/迁移 | 无 |
| `lib/models/venue.dart` | 无 |
| `lib/features/venue/venue_detail_screen.dart` | 无 |
