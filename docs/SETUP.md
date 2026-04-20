# 生产配置清单

本文件列出上线前需要准备的 API key、证书、审批项，以及写入哪里。
代码侧已全部占位，只等你填空。

---

## 1 · Supabase

| 项 | 来源 | 用途 |
|---|---|---|
| `SUPABASE_URL` | Supabase Dashboard → Settings → API | 所有客户端/服务端 |
| `SUPABASE_ANON_KEY` | 同上 | 客户端 RLS 受限访问 |
| `SUPABASE_SERVICE_ROLE_KEY` | 同上（**不进仓**）| Edge Function / 定时任务 |

**Storage buckets（Dashboard → Storage）**  
新建 3 个 public bucket：`avatars` / `event-covers` / `pickup-photos`，
并跑 `docs/storage-policies.sql` 里的 RLS policies。

---

## 2 · 图片（S1）— 已编码完成

无额外审批。只要 buckets 建好就能用。

---

## 3 · 地图（S2）— 已选高德

代码已用 `amap_flutter_map` 接入，并通过 `lib/features/pickup/map/real_map.dart`
的条件导入让 web 回落到 SVG canvas（`real_map_stub.dart`）。

### 申请 Amap key

1. https://lbs.amap.com → 注册/登录 → 我的应用 → 创建新应用（名称"开球"）
2. Android key：
   - Package name: `com.kaiqiu.gameon`
   - SHA-1: `keytool -list -v -keystore release.keystore -alias kaiqiu`
     取 Certificate fingerprints 里的 SHA1
3. iOS key：
   - Bundle ID: `com.kaiqiu.gameon`
4. （可选）Web 服务 key：要在服务端地理编码时用

### 注入方式

- **CI**：在 GitHub Secrets 加 `AMAP_IOS_KEY` + `AMAP_ANDROID_KEY`，
  release-android.yml 已同时暴露为 `ORG_GRADLE_PROJECT_AMAP_ANDROID_KEY`
  给 native manifest placeholder。
- **本地 iOS**：在 Xcode scheme 里加 `AMAP_IOS_KEY` env var；Info.plist
  会通过 `$(AMAP_IOS_KEY)` 插值。或者直接改 plist 值（不推荐进仓）。
- **本地 Android**：在 `~/.gradle/gradle.properties` 加
  `AMAP_ANDROID_KEY=...`。
- **Dart 侧**：`--dart-define=AMAP_IOS_KEY=... --dart-define=AMAP_ANDROID_KEY=...`
  （仅用于 `AMapApiKey(...)` 构造，和 native manifest 里的值必须一致）。

---

## 4 · 推送（S4）— 代码骨架已就位

### 4.1 Firebase project
1. 访问 https://console.firebase.google.com → 新建 project：`kaiqiu-prod`（和可选 `kaiqiu-dev`）。
2. 添加 iOS app，bundle id `com.kaiqiu.gameon`，下载 `GoogleService-Info.plist` → `ios/Runner/`。
3. 添加 Android app，package name `com.kaiqiu.gameon`，下载 `google-services.json` → `android/app/`。
4. Cloud Messaging → 上传 APNs Auth Key（需 Apple Developer）。

### 4.2 Firebase dart-defines
| 项 | 来源（Firebase Console）| 用途 |
|---|---|---|
| `FIREBASE_API_KEY` | Project settings → 你的 app → Web API Key | `PushService._firebaseOptions()` |
| `FIREBASE_APP_ID` | 同上 → App ID | 同上 |
| `FIREBASE_MESSAGING_SENDER_ID` | 同上 → Sender ID | 同上 |
| `FIREBASE_PROJECT_ID` | 同上 → Project ID | 同上 |

> 推荐：跑 `flutterfire configure` 自动生成 `lib/firebase_options.dart`，
> 然后把 `push.dart` 里的 `_firebaseOptions()` 切成读取 `DefaultFirebaseOptions.currentPlatform`。

### 4.3 Edge Function secrets
`supabase secrets set FCM_SERVICE_ACCOUNT='<base64-encoded service-account.json>'`

> Service account JSON 从 Firebase → Project settings → Service accounts
> → Generate new private key → 下载后 `base64 -w0 < file.json`。

### 4.4 pg_cron
Dashboard → Database → Extensions 启用 `pg_cron` + `pg_net`；
然后按 `supabase/migrations/0019_reminders_cron.sql` 里的说明手动跑（替换 `<PROJECT_REF>`）。

### 4.5 国内分发
已决定**不接** JPush/个推。FCM 在中国大陆网络下送达率受限，这是已知取舍。
真要解决再另起方案。

---

## 5 · CI/CD（S5）

### 5.1 GitHub Secrets（Settings → Secrets and variables → Actions）

**必填（主分支 PR check）**
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

**Android release**（打 tag 时触发）
- `ANDROID_KEYSTORE_B64` — `base64 -w0 release.keystore`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `PLAY_STORE_SERVICE_ACCOUNT` — JSON of GCP service account with
  "Google Play Android Developer" role

**Firebase（任何 release）**
- `FIREBASE_API_KEY`
- `FIREBASE_APP_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_PROJECT_ID`

**地图（S2 完成后）**
- `AMAP_IOS_KEY`
- `AMAP_ANDROID_KEY`

**iOS release**（workflow 在 `workflows-disabled/`，Apple 账号到位后启用）
- `APPLE_CERT_P12`
- `APPLE_CERT_PASSWORD`
- `APPLE_ISSUER_ID`
- `APPLE_KEY_ID`
- `APPLE_PRIVATE_KEY`
- `APPLE_TEAM_ID`

### 5.2 生成 Android signing keystore（一次性）

```bash
keytool -genkey -v -keystore release.keystore \
  -alias kaiqiu -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 release.keystore   # 放到 ANDROID_KEYSTORE_B64
```

### 5.3 Google Play service account

1. https://console.cloud.google.com 选 project → IAM → Service accounts → 新建
2. 授权 "Google Play Android Developer" role
3. Keys → Add key → JSON → 下载
4. Play Console → Users and permissions → 邀请该 service account，赋 Release manager 权限

### 5.4 Apple Developer（iOS CI/CD 前置）
- $99/年；审批 1-3 天
- App Store Connect 创建 app（bundle `com.kaiqiu.gameon`）
- Certificates → Distribution cert → 导出 `.p12`
- Users & Access → Keys → App Store Connect API → 创建 key → 下载 `.p8`

### 5.5 Web 预览
推荐 **Cloudflare Pages**（免费 + 每 PR 自动预览）：
1. 登录 dash.cloudflare.com → Pages → 连接 GitHub repo
2. Build command: `flutter build web --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY`
3. Output: `build/web`
4. 环境变量里塞 Supabase URL + anon key
5. PR 自动出预览 URL

---

## 6 · Sanity check

跑完配置后：
```bash
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=...
```
看 console：
- 有 `[kaiqiu] Supabase not configured` → `SUPABASE_*` 没传。
- 有 `[push] Firebase not configured` → `FIREBASE_*` 没传（code 会静默跳过，符合预期）。
- 都没这两行 → 生产模式就绪。
