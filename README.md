# 开球 · GameOn — Flutter App

业余球类运动社交 App · 约球 + 赛事 + 评分

> 用开球，组一局。

## 技术栈

- **Flutter 3.41** + **Dart 3.11**
- **Supabase** — 认证、Postgres、Realtime、Storage
- **go_router** — 声明式路由
- **flutter_riverpod** — 状态管理
- **supabase_flutter** — 官方 SDK
- **flutter_map** — 开源地图（后期换成高德/腾讯地图 SDK）

## 目录结构

```
qiuju_app/
├── lib/
│   ├── main.dart
│   ├── app.dart                 # MaterialApp + router
│   ├── config/
│   │   └── env.dart             # Supabase URL / anon key
│   ├── theme/
│   │   ├── tokens.dart          # 颜色、字号、间距（设计系统）
│   │   └── theme.dart           # ThemeData 封装
│   ├── widgets/                 # 共享组件（Avatar, Chip, LivePill, ...）
│   ├── models/                  # 数据模型（Pickup, Event, Rating, ...）
│   ├── services/
│   │   └── supabase.dart        # 客户端 + helper
│   ├── repositories/            # 数据存取（薄封装）
│   ├── features/
│   │   ├── home/
│   │   ├── pickup/
│   │   ├── events/
│   │   ├── create_event/
│   │   ├── profile/
│   │   ├── messages/
│   │   └── rating/
│   └── routes.dart              # go_router 配置
├── supabase/
│   └── migrations/              # SQL 文件，在 Supabase SQL Editor 依次执行
│       ├── 0001_profiles.sql
│       ├── 0002_pickups.sql
│       ├── 0003_events_ratings.sql
│       └── 0004_messages.sql
├── android/ · ios/              # 原生壳
└── pubspec.yaml
```

## 一次性设置

### 1. Supabase 项目
1. 到 https://supabase.com 建项目（参考主仓库 README 里的建项目步骤）
2. 打开 **SQL Editor**，依次粘贴执行 `supabase/migrations/` 下的 4 个 SQL 文件
3. **Project Settings → API** 复制 `Project URL` 和 `anon public key`

### 2. 本地环境变量
新建 `lib/config/env.dart`（**不要提交**，已在 `.gitignore`）：

```dart
// lib/config/env.dart
class Env {
  static const supabaseUrl = 'https://xxxxx.supabase.co';
  static const supabaseAnonKey = 'eyJhbGc...';
}
```

或更安全：用 `--dart-define` 在运行时注入（见下）。

### 3. 安装依赖
```bash
flutter pub get
```

### 4. 运行
```bash
# iOS 模拟器
flutter run -d iPhone

# Android 模拟器
flutter run -d android

# 用 --dart-define 注入 Supabase 配置（推荐）
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGc...
```

## 开发命令

| 命令 | 用途 |
|---|---|
| `flutter pub get` | 装依赖 |
| `flutter analyze` | 静态分析 |
| `flutter test` | 跑单元测试 |
| `dart format lib/` | 格式化 |
| `flutter build apk` | 打 Android 包 |
| `flutter build ios` | 打 iOS 包 |

## 后续路线图（基础设施之后）

- [ ] Phase 1：填 UI — 9 屏逐个用真数据实现
- [ ] Phase 2：接高德地图 SDK 替换占位地图
- [ ] Phase 3：接阿里云/腾讯云短信网关启用手机号登录
- [ ] Phase 4：IM 换成 Supabase Realtime 生产就绪 / 接环信
- [ ] Phase 5：CI + TestFlight + 小规模内测
