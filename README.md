# 开球 · GameOn — Flutter App

**中文** · [English](README.en.md)

业余球类运动社交 App · 约球 + 赛事 + 评分

> 用开球，组一局。

## 品牌

| 维度 | 值 |
|---|---|
| 中文名 | 开球 |
| 英文名 | GameOn |
| Bundle ID | `cn.kaiqiu.app` |
| Dart 包名 | `kaiqiu_app` |
| 操作系统目录 | `qiuju_app/`（未改名，历史原因） |

重命名决策记录：[docs/superpowers/specs/2026-04-20-rebrand-kaiqiu-gameon-design.md](docs/superpowers/specs/2026-04-20-rebrand-kaiqiu-gameon-design.md)

## 技术栈

- **Flutter 3.41+** / **Dart 3.11+**
- **Supabase** —— 认证 / Postgres / Realtime / Storage（BaaS，无需自建服务端）
- **go_router** —— 声明式路由
- **flutter_riverpod** —— 状态管理
- **supabase_flutter** —— 官方 SDK
- **intl** —— 日期 / 数字本地化

## 目录结构

```
qiuju_app/                      # OS 目录（package 名是 kaiqiu_app）
├── lib/
│   ├── main.dart               # 入口
│   ├── app.dart                # KaiqiuApp + MaterialApp.router
│   ├── routes.dart             # go_router 路由配置
│   ├── providers.dart          # 全局 Riverpod providers
│   ├── config/env.dart         # Supabase URL / anon key（编译期注入）
│   ├── theme/                  # ThemeData + 设计 tokens
│   ├── widgets/                # 共享组件（Avatar, Chip, LivePill, ...）
│   ├── models/                 # 数据模型（Pickup, Event, Rating, ...）
│   ├── services/supabase.dart  # Supabase 客户端 helper
│   ├── repositories/           # 数据存取薄封装
│   ├── data/mock.dart          # 离线原型数据（scaffold 阶段用）
│   └── features/
│       ├── auth/               # 登录注册
│       ├── home/               # 首页
│       ├── pickup/             # 约球（列表 / 地图 / 详情）
│       ├── events/             # 赛事
│       ├── create_event/       # 发起局
│       ├── messages/           # IM
│       ├── profile/            # 个人中心
│       └── rating/             # 评分
├── supabase/
│   ├── migrations/             # 数据库 schema 演进（0001-0009）
│   └── seed/                   # demo 数据（01-04）
├── android/ · ios/ · web/      # 原生壳（Android + iOS + Web）
├── test/widget_test.dart       # smoke 测试
├── .github/workflows/build.yml # CI：打 Android APK + iOS IPA
├── docs/superpowers/specs/     # 设计决策文档
├── IMPLEMENTATION_PLAN.md      # 9 屏实现计划
└── pubspec.yaml
```

## 快速开始

### 1. 安装 Flutter

需要 Flutter 3.41+（`dart sdk: ^3.11.5`）。
参考 https://docs.flutter.dev/get-started/install 按系统装。

确认：
```bash
flutter --version
flutter doctor
```

### 2. 安装依赖

```bash
flutter pub get
```

### 3. Supabase 后端

**方式 A：用默认凭证（开箱即用，指向共享 demo 项目）**

`lib/config/env.dart` 里已经有一套默认 URL + anon key，直接跑即可。

**方式 B：自建项目（生产推荐）**

1. 到 https://supabase.com 建新项目
2. 打开 **SQL Editor**，按顺序执行 `supabase/migrations/` 下的 9 个 SQL 文件
3. 如果需要 demo 数据，再跑 `supabase/seed/` 下的 4 个文件
4. 在 **Project Settings → API** 复制 `Project URL` 和 `anon public key`
5. 运行时通过 `--dart-define` 注入（见下节），或编辑 `lib/config/env.dart` 里的默认值

> Supabase `anon` key 设计为可随客户端分发，安全由数据库 Row Level Security (RLS) 策略保障。即便如此，生产发布仍建议走 `--dart-define` 而不是把 key 提交进仓库。

### 4. 本地运行

```bash
# 看有哪些设备 / 模拟器可用
flutter devices

# 用默认 Supabase 凭证跑
flutter run

# 指定设备（device id 从 flutter devices 拿）
flutter run -d <device-id>

# 注入自建 Supabase 凭证
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGc...
```

## 打包 Android

```bash
# Release APK（当前用 debug 签名，可装任何 Android 手机测试，不能上架）
flutter build apk --release

# Release AAB（上架 Google Play 用）
flutter build appbundle --release
```

产物路径：
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

**装到手机**：把 APK 传过去（数据线 / 微信文件传输助手 / adb），手机设置允许"未知来源"安装即可。

**上架 Google Play** 需要先配置 release 签名密钥，参考 [Android docs · Signing](https://developer.android.com/studio/publish/app-signing)。

## 打包 iOS

需要 **macOS + Xcode**（Linux / Windows 无法直接打包 iOS）。

```bash
cd ios && pod install && cd ..

# 编译（不签名 —— 得到 Runner.app，不能直接装 iPhone）
flutter build ios --release --no-codesign

# 编译 + 打签名 IPA（需要 Apple Developer 账号 $99/年）
flutter build ipa --release
```

产物路径：
- unsigned: `build/ios/iphoneos/Runner.app`
- signed IPA: `build/ios/ipa/*.ipa`

**没有 Apple Developer 账号时装 iPhone 的路径**：
1. **Sideloadly**（免费，跨平台）—— 把 unsigned IPA 拖进去，输入免费 Apple ID 即可签名 + 安装；有效期 7 天，过期重签
2. **Xcode 手动签**（需 Mac）—— 打开 `ios/Runner.xcworkspace`，Signing & Capabilities 里选免费 Apple ID → Personal Team → 运行到已连 iPhone

首次安装后，去 **设置 → 通用 → VPN 与设备管理 → 信任开发者** 才能启动 App。

## GitHub Actions（CI 打包）

workflow 在 `.github/workflows/build.yml`，触发条件：
- Push 到 `main` / `master` 分支
- PR 提交
- Actions 页面手动 `Run workflow`

两个 job 并行：

| Job | Runner | 产物 | 说明 |
|---|---|---|---|
| `android` | ubuntu-latest | `kaiqiu-android-apk` | debug-signed APK，可直接装 Android |
| `ios` | macos-latest | `kaiqiu-ios-unsigned-ipa` | unsigned，需 Sideloadly / Xcode 重签 |

**（可选）配 Supabase Secrets**：仓库 → Settings → Secrets and variables → Actions，加 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY`。不配时 workflow 会 fallback 到 `lib/config/env.dart` 的默认值。

**下载产物**：Actions 页面 → 选中 run → 最下方 Artifacts 区下载 zip。

## 开发命令

| 命令 | 用途 |
|---|---|
| `flutter pub get` | 装依赖 |
| `flutter pub outdated` | 查依赖更新 |
| `flutter analyze` | 静态分析 |
| `flutter test` | 跑 widget / unit 测试 |
| `dart format lib/ test/` | 格式化 |
| `flutter run` | 本地运行 |
| `flutter build apk --release` | 打 Android release |
| `flutter build ios --release --no-codesign` | 打 iOS unsigned |

## 后续路线图

- [x] Phase 0：基础设施（scaffold、Supabase migrations、CI）
- [ ] Phase 1：填 UI —— 9 屏逐个用真数据实现（见 `IMPLEMENTATION_PLAN.md`）
- [ ] Phase 2：地图 SDK（从占位切换到高德 / 腾讯地图）
- [ ] Phase 3：手机号登录（接阿里云 / 腾讯云短信网关）
- [ ] Phase 4：IM 生产化（Supabase Realtime 或接环信）
- [ ] Phase 5：TestFlight + 小规模内测
- [ ] Phase 6：App Store / Google Play 上架

## 设计 / 决策文档

- [品牌重命名：开球 · GameOn](docs/superpowers/specs/2026-04-20-rebrand-kaiqiu-gameon-design.md)
- [实现计划（9 屏）](IMPLEMENTATION_PLAN.md)
