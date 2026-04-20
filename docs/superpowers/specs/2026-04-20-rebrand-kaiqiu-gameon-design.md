# 品牌更名设计：开球 · GameOn

**日期**: 2026-04-20
**决策人**: 项目 owner
**状态**: 已批准，待实施

## 决定

产品从**球局 (Qiuju)** 更名为 **开球 · GameOn**。

- **中文名**：开球（主品牌，国内市场）
- **英文名**：GameOn（国际品牌、海外华人、英文 App Store 标题）
- **合并展示**：开球 · GameOn（App 首屏、官网、About 页）

## 命名理由

- **号召感 / 动作词**：开球是动词，用户第一动作（发起一场局）= App 名，记忆内化
- **全品类覆盖**：每种球类都有"开球"这一起手动作（跳球、发球、开杆、开脚）
- **中文差异化**：当前中文 App 市场未发现同名产品
- **双关叙事**：App 叫"开球"，用户在 App 里组织的东西叫"球局"——
  "用开球，组一局" 成为天然 slogan
- **英文 GameOn 地道**："Game On!" 是"开球了！"的直接英文口语对应，跨品类、年轻

## Bundle ID / 包名迁移

- 旧：`cn.qiuju.qiuju_app`（Android）/ `cn.qiuju.qiujuApp`（iOS）
- 新：**`cn.kaiqiu.app`**（Android + iOS 统一）
- 理由：Bundle ID 一旦上架永久不可改；当前尚未推送仓库和上架，现在是零成本改名的最后窗口

## 字符串分级处理

代码里 "球局" 有两种语义，不一刀切：

### 改为"开球"（品牌指称，8 处）

- `lib/app.dart` MaterialApp.title
- `lib/features/auth/sign_in_screen.dart` 登录页主品牌字
- `lib/features/profile/profile_screen.dart` "关于球局" → "关于开球"
- `lib/features/messages/chat_screen.dart` "球局 · 新手大厅" → "开球 · 新手大厅"
- `android/app/src/main/AndroidManifest.xml` `android:label`
- `ios/Runner/Info.plist` `CFBundleDisplayName`
- `web/index.html` `<title>` + `apple-mobile-web-app-title`
- `web/manifest.json` `name` + `short_name`
- `README.md` 首行标题
- `pubspec.yaml` description

### 保留"球局"（普通名词：一场球的会话，4 处）

- `pickup_map_screen.dart` "同城 N 个球局"
- `pickup_detail_screen.dart` 注释"球局详情"
- `profile_screen.dart` "我组织的球局"

### 开发者层（可选，cosmetic）

- Dart class `QiujuApp` → `KaiqiuApp`
- 文件注释 "the 球局 app" → "the 开球 app"
- main.dart 日志前缀 `[qiuju]` → `[kaiqiu]`

## 保留不变（避免连锁改动）

- Dart package name: `qiuju_app`（用户不可见；改要动所有 import）
- Supabase 项目 URL（后端技术资源，与品牌解耦）

## 本次 out-of-scope

- Logo / App Icon 设计
- 商标注册 / 域名购买（建议单独跟进 `kaiqiu.cn` / `gameon.app`）
- Supabase 项目改名
- App Store / Play Store 上架文案

## 实施顺序

1. 字符串批量替换（用户可见 + 开发者层）
2. Bundle ID 迁移（Android build.gradle.kts + Kotlin 包路径移动 + iOS pbxproj）
3. 本地 `flutter analyze` 验证无编译破坏
4. Amend 首次 init commit
