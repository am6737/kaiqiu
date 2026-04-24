# 注册后引导页设计

## 概述

注册（含匿名登录）后增加一个轻量引导页，让用户设置昵称和头像，替代默认的"新球友"+无头像体验。

## 触发条件

已登录用户，profile 满足 `name == '新球友'` 且 `avatar_url == null` 时，路由 redirect 拦截到 `/onboarding`。

即使用户杀掉 app 重新打开，只要 profile 未完善就会再次进入引导页。

## 路由变更

`routes.dart` redirect 逻辑扩展为三层：

```
未登录                        → /sign-in
已登录 + 未完成引导             → /onboarding
已登录 + 已完成引导             → 放行（/home 等）
```

判定"未完成引导"：GoRouter redirect 是同步的，不能直接 await 网络请求。方案：在 `OnboardingScreen` 自身做判断——页面 initState 中 fetch profile，如果已完善则立即 `context.go('/home')`，否则展示表单。路由 redirect 仅做简单判断：已登录时放行（让 OnboardingScreen 或 Home 自己处理）。

实际的跳转链路：
1. 注册/匿名登录成功 → `sign_in_screen` 中直接 `context.go('/onboarding')` 而非等 router redirect
2. 老用户登录 → router redirect 照常跳 `/home`
3. 用户杀掉 app 重开 → redirect 判断已登录放行到 `/home`，`HomeScreen` 或 shell 层检查 profile 是否完善，未完善则跳 `/onboarding`

新增路由：`GoRoute(path: '/onboarding', builder: ... OnboardingScreen)`。

## 引导页 UI

**文件**：`lib/features/auth/onboarding_screen.dart`

**布局（从上到下）**：

1. **标题** — "完善个人信息"，副标题 "随时可以在个人主页修改"
2. **头像** — 居中 96px 圆形，初始随机选一个预设头像。点击弹出现有 `showAvatarPickerSheet()`（12 个预设 + 自定义上传，完全复用）
3. **昵称输入框** — 预填随机组合词，右侧骰子图标按钮点击重新随机
4. **"开始使用"按钮** — PrimaryButton，full width，点击后写入 profile 并跳转首页

**无返回按钮**，用户必须完成此页。

## 随机昵称生成

纯客户端，两个词表随机组合：

- **形容词**（~20 个）：闪电、暴力、飞天、无敌、黄金、钢铁、疾风、烈焰、影子、极速、神秘、狂野、不败、超级、传奇、冰霜、雷霆、幻影、旋风、铁壁
- **角色**（~20 个）：前锋、后卫、门将、中场、边锋、队长、射手、铁卫、核弹头、指挥官、守护者、突击手、全能王、大师、新星、猎手、战神、先锋、王牌、精灵

组合方式：随机形容词 + 随机角色 = ~400 种组合。

实现位置：`lib/utils/random_name.dart`，一个纯函数 `String generateRandomName()`。

## "开始使用"按钮行为

1. 校验昵称非空
2. 调用 `ProfilesRepository.update(uid, { 'name': name, 'avatar_url': avatarUrl })`
3. 成功后 `context.go('/home')`（路由 redirect 不再拦截，因为条件不满足了）
4. 失败显示 toast 错误

## 对现有代码的影响

| 文件 | 变更 |
|------|------|
| `lib/routes.dart` | redirect 增加 onboarding 判断，新增 `/onboarding` 路由 |
| `lib/features/auth/onboarding_screen.dart` | **新文件** |
| `lib/utils/random_name.dart` | **新文件** |
| `lib/l10n/app_zh.arb` | 添加 onboarding 相关翻译键 |
| `lib/l10n/app_en.arb` | 添加 onboarding 相关翻译键 |
| `lib/features/auth/sign_in_screen.dart` | 注册后 signUp 返回 session==null 时的 toast 处理（已修复） |

不改数据库 schema，不改 profile model，不改现有 avatar picker 组件。

## 新增 l10n 键

| Key | 中文 | English |
|-----|------|---------|
| `onboarding_title` | 完善个人信息 | Set up your profile |
| `onboarding_subtitle` | 随时可以在个人主页修改 | You can change this later |
| `onboarding_name_label` | 昵称 | Nickname |
| `onboarding_submit` | 开始使用 | Get started |
| `onboarding_name_empty` | 请输入昵称 | Please enter a nickname |
