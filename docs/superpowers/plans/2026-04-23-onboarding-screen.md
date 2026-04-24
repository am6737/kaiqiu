# 注册后引导页 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 注册/匿名登录后显示一个轻量引导页，让用户设置昵称和头像，替代默认的"新球友"+无头像。

**Architecture:** 新增 `/onboarding` 路由和 `OnboardingScreen` 页面。注册成功后直接跳转到引导页；老用户重开 app 时在 shell 层检查 profile 是否完善，未完善则重定向。复用现有 `showAvatarPickerSheet` + `StorageService` + `ProfilesRepository`。

**Tech Stack:** Flutter, Riverpod, GoRouter, Supabase Auth + Storage

**Spec:** `docs/superpowers/specs/2026-04-23-onboarding-screen-design.md`

---

### File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `lib/utils/random_name.dart` | 随机昵称生成（形容词+角色词表） |
| Create | `lib/features/auth/onboarding_screen.dart` | 引导页 UI（头像+昵称+提交） |
| Modify | `lib/routes.dart:50-62` | 新增 `/onboarding` 路由 |
| Modify | `lib/features/auth/sign_in_screen.dart:56-63` | 注册/匿名成功后跳 `/onboarding` |
| Modify | `lib/widgets/bottom_nav_shell.dart` | shell 层检查 profile 完善状态 |
| Modify | `lib/l10n/app_zh.arb` | 新增 onboarding 相关中文翻译 |
| Modify | `lib/l10n/app_en.arb` | 新增 onboarding 相关英文翻译 |

---

### Task 1: 随机昵称生成工具

**Files:**
- Create: `lib/utils/random_name.dart`

- [ ] **Step 1: Create `random_name.dart`**

```dart
// random_name.dart — 随机昵称生成
import 'dart:math';

const _adjectives = [
  '闪电', '暴力', '飞天', '无敌', '黄金',
  '钢铁', '疾风', '烈焰', '影子', '极速',
  '神秘', '狂野', '不败', '超级', '传奇',
  '冰霜', '雷霆', '幻影', '旋风', '铁壁',
];

const _roles = [
  '前锋', '后卫', '门将', '中场', '边锋',
  '队长', '射手', '铁卫', '核弹头', '指挥官',
  '守护者', '突击手', '全能王', '大师', '新星',
  '猎手', '战神', '先锋', '王牌', '精灵',
];

final _rng = Random();

String generateRandomName() {
  final adj = _adjectives[_rng.nextInt(_adjectives.length)];
  final role = _roles[_rng.nextInt(_roles.length)];
  return '$adj$role';
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `/home/coder/flutter/bin/flutter analyze lib/utils/random_name.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/utils/random_name.dart
git commit -m "feat(onboarding): add random nickname generator"
```

---

### Task 2: 添加 l10n 翻译键

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`

- [ ] **Step 1: Add keys to `app_zh.arb`**

在 `auth_anon_failed` 行之后、`rate_title` 行之前添加：

```json
  "onboarding_title": "完善个人信息",
  "onboarding_subtitle": "随时可以在个人主页修改",
  "onboarding_name_label": "昵称",
  "onboarding_submit": "开始使用",
  "onboarding_name_empty": "请输入昵称",
  "onboarding_save_fail": "保存失败",
```

- [ ] **Step 2: Add keys to `app_en.arb`**

同样位置添加：

```json
  "onboarding_title": "Set up your profile",
  "onboarding_subtitle": "You can change this later",
  "onboarding_name_label": "Nickname",
  "onboarding_submit": "Get started",
  "onboarding_name_empty": "Please enter a nickname",
  "onboarding_save_fail": "Save failed",
```

- [ ] **Step 3: Regenerate l10n**

Run: `/home/coder/flutter/bin/flutter gen-l10n`
Expected: No errors

- [ ] **Step 4: Verify generated code has new keys**

Run: `grep 'onboarding_title' lib/l10n/generated/app_localizations.dart`
Expected: Matches found

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/
git commit -m "feat(onboarding): add l10n keys for onboarding screen"
```

---

### Task 3: 创建 OnboardingScreen

**Files:**
- Create: `lib/features/auth/onboarding_screen.dart`

- [ ] **Step 1: Create `onboarding_screen.dart`**

```dart
// onboarding_screen.dart — 注册后引导页（昵称+头像）
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../services/storage.dart';
import '../../services/supabase.dart';
import '../../theme/app_tokens.dart';
import '../../utils/random_name.dart';
import '../../utils/toast.dart';
import '../../widgets/avatar_picker_sheet.dart';
import '../../widgets/network_avatar.dart';
import '../../widgets/preset_avatars.dart';
import '../../widgets/primary_button.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  late String _avatarUrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.text = generateRandomName();
    _avatarUrl = presetUrl(Random().nextInt(kPresetImageUrls.length));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final result = await showAvatarPickerSheet(
      context,
      current: _avatarUrl,
      name: _name.text,
    );
    if (result == null || !mounted) return;

    if (result == kUploadCustom) {
      final uid = currentUserId;
      if (uid == null) return;
      final url = await StorageService().pickCropCompressAndUpload(
        bucket: 'avatars',
        pathPrefix: uid,
        square: true,
      );
      if (url != null && mounted) setState(() => _avatarUrl = url);
      return;
    }

    setState(() => _avatarUrl = result);
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final name = _name.text.trim();
    if (name.isEmpty) {
      showToast(context, l.onboarding_name_empty, error: true);
      return;
    }

    final uid = currentUserId;
    if (uid == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(profilesRepoProvider).update(uid, {
        'name': name,
        'avatar_url': _avatarUrl,
      });
      ref.invalidate(myProfileProvider);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        showToast(context, '${l.onboarding_save_fail}: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Text(
                l.onboarding_title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: tokens.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.onboarding_subtitle,
                style: TextStyle(fontSize: 14, color: tokens.inkSub),
              ),
              const Spacer(flex: 2),
              GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    NetworkAvatar(_name.text, url: _avatarUrl, size: 96),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: tokens.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 14,
                          color: tokens.accentInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.onboarding_name_label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tokens.inkSub,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: tokens.elev2,
                      border: Border.all(color: tokens.line),
                      borderRadius: BorderRadius.circular(tokens.r2),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _name,
                            style: TextStyle(
                              color: tokens.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _name.text = generateRandomName()),
                          child: Icon(
                            Icons.casino_outlined,
                            size: 22,
                            color: tokens.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: _busy ? l.common_loading : l.onboarding_submit,
                full: true,
                variant: BtnVariant.primary,
                size: BtnSize.lg,
                disabled: _busy,
                onPressed: _submit,
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `/home/coder/flutter/bin/flutter analyze lib/features/auth/onboarding_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/features/auth/onboarding_screen.dart
git commit -m "feat(onboarding): create onboarding screen with avatar + nickname"
```

---

### Task 4: 修改路由和登录流程

**Files:**
- Modify: `lib/routes.dart:50-62`
- Modify: `lib/features/auth/sign_in_screen.dart:56-63`

- [ ] **Step 1: Add `/onboarding` route to `routes.dart`**

在 `routes.dart` 顶部 import 区添加：

```dart
import 'features/auth/onboarding_screen.dart';
```

在 redirect 函数中增加 onboarding 判断——当已登录用户在 `/onboarding` 页面时放行：

将 `routes.dart:53-59` 的 redirect 改为：

```dart
  redirect: (ctx, state) {
    final signedIn = supabase.auth.currentUser != null;
    final atSignIn = state.matchedLocation == '/sign-in';
    final atOnboarding = state.matchedLocation == '/onboarding';
    if (!signedIn && !atSignIn) return '/sign-in';
    if (signedIn && atSignIn) return '/home';
    if (!signedIn && atOnboarding) return '/sign-in';
    return null;
  },
```

在 routes 列表中，`/sign-in` 路由之后添加：

```dart
    GoRoute(path: '/onboarding', builder: (_, s) => const OnboardingScreen()),
```

- [ ] **Step 2: Modify `sign_in_screen.dart` `_submit()` to navigate to `/onboarding` after signup**

将 `sign_in_screen.dart:56-63` 替换为：

```dart
    try {
      if (_isNewUser) {
        final res = await supabase.auth.signUp(email: email, password: pwd);
        await LocalStore.setRemember(_remember, _remember ? email : null);
        if (res.session == null) {
          if (mounted) {
            showToast(context, l.auth_signup_check_email, success: true);
          }
          return;
        }
        if (mounted) context.go('/onboarding');
        return;
      } else {
        await supabase.auth.signInWithPassword(email: email, password: pwd);
        await LocalStore.setRemember(_remember, _remember ? email : null);
      }
      // Router redirect will fire automatically for login.
```

- [ ] **Step 3: Modify `_anonymous()` to navigate to `/onboarding`**

将 `sign_in_screen.dart:83-97` 的 `_anonymous()` 方法替换为：

```dart
  Future<void> _anonymous() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.auth.signInAnonymously();
      if (mounted) context.go('/onboarding');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
```

注意：不再传 `data: {'name': _randomGuestName()}`，因为昵称会在引导页设置。

- [ ] **Step 4: Add `auth_signup_check_email` l10n key (if missing)**

检查 `app_zh.arb` 和 `app_en.arb` 是否已有 `auth_signup_check_email` 键。如缺失则添加：

`app_zh.arb`（在 `auth_signup_failed` 行后）：
```json
  "auth_signup_check_email": "注册成功！请查看邮箱并点击确认链接",
```

`app_en.arb`（同位置）：
```json
  "auth_signup_check_email": "Signed up! Please check your email to confirm",
```

然后运行: `/home/coder/flutter/bin/flutter gen-l10n`

- [ ] **Step 5: Add go_router import to `sign_in_screen.dart`**

在 `sign_in_screen.dart` import 区添加：

```dart
import 'package:go_router/go_router.dart';
```

- [ ] **Step 6: Verify no analysis errors**

Run: `/home/coder/flutter/bin/flutter analyze lib/routes.dart lib/features/auth/sign_in_screen.dart`
Expected: No issues found

- [ ] **Step 7: Commit**

```bash
git add lib/routes.dart lib/features/auth/sign_in_screen.dart lib/l10n/
git commit -m "feat(onboarding): wire up routing and post-signup navigation"
```

---

### Task 5: Shell 层检查 profile 完善状态

**Files:**
- Modify: `lib/widgets/bottom_nav_shell.dart`

- [ ] **Step 1: Read current `bottom_nav_shell.dart`**

先完整阅读文件，确认 build 方法结构。

- [ ] **Step 2: Add profile check in `initState` or `build`**

在 `BottomNavShell`（应为 ConsumerStatefulWidget 或 ConsumerWidget）中，添加一次性检查：

```dart
import 'package:go_router/go_router.dart';
import '../providers.dart';
```

在 build 方法开头或 initState 中添加：

```dart
ref.listen(myProfileProvider, (_, next) {
  final profile = next.valueOrNull?.profile;
  if (profile != null &&
      profile.name == '新球友' &&
      profile.avatarUrl == null) {
    context.go('/onboarding');
  }
});
```

这样老用户重开 app、profile 加载完成后，如果发现未完善就自动跳到引导页。

- [ ] **Step 3: Verify no analysis errors**

Run: `/home/coder/flutter/bin/flutter analyze lib/widgets/bottom_nav_shell.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/bottom_nav_shell.dart
git commit -m "feat(onboarding): redirect incomplete profiles from shell"
```

---

### Task 6: 端到端验证

- [ ] **Step 1: Full analysis**

Run: `/home/coder/flutter/bin/flutter analyze`
Expected: No issues found (or only pre-existing warnings)

- [ ] **Step 2: Manual test — 邮箱注册流程**

1. 启动 app
2. 在登录页输入新邮箱+密码，点击"注册"
3. 预期：注册成功后跳转到引导页
4. 引导页有随机头像和随机昵称
5. 点骰子按钮，昵称更换
6. 点头像，弹出 picker，选择一个预设头像
7. 点"开始使用"
8. 预期：跳转到首页，个人主页显示新昵称和头像

- [ ] **Step 3: Manual test — 匿名登录流程**

1. 退出登录回到登录页
2. 点击"游客登录"
3. 预期：跳转到引导页（不是直接进首页）
4. 完成昵称+头像设置后进首页

- [ ] **Step 4: Manual test — 杀 app 重开**

1. 注册新用户但不完成引导（在引导页杀掉 app）
2. 重新打开 app
3. 预期：进入首页后检测到 profile 未完善，自动跳转到引导页

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat(onboarding): post-signup profile setup screen

Add lightweight onboarding screen after registration/anonymous login.
Users set nickname (random fun name) and avatar before entering the app.
Shell layer redirects incomplete profiles back to onboarding."
```
