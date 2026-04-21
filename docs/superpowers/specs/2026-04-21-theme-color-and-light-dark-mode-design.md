# 主题色配置与明暗主题切换 设计文档

**Status:** Draft
**Date:** 2026-04-21
**Owner:** am6737

## 一、目标

为「开球 GameOn」App 增加两项用户可控的外观配置:

1. **主题模式**:跟随系统 / 浅色 / 深色 三选一,默认跟随系统
2. **主题色(强调色)**:4 个预设色板 + 自定义取色,覆盖浅 / 深两种模式

## 二、约束与不做的事

**做:**

- 重新设计一套精致的浅色色板(暖白 / 米调底色,克制的灰阶层次)
- 强调色为浅 / 深各调一套最佳值,保证 WCAG AA 对比度
- 自定义颜色派生 + 对比度兜底逻辑
- 即选即生效、无保存按钮、平滑动画过渡
- 把现有静态 token 系统迁移到 Material `ThemeExtension`

**不做(YAGNI):**

- 不做颜色完全自由(无对比度兜底)的"任意配色"
- 不做字体大小、动效开关、紧凑模式等其他外观设置(为未来留扩展点,本期不实现)
- 不做主题色对图标 / 插图的批量重染色(只影响 `accent` token 的使用点)
- 不做 system theme 的"跟随时间自动切换"模拟

## 三、架构总览

```
用户操作:外观设置页
    ↓ 写入
LocalStore (SharedPreferences) — 新增 themeMode / themeSeed 两键
    ↓ 读取
ThemeController (ChangeNotifier 单例,镜像 LocaleController 模式)
    ─ mode: ThemeMode
    ─ seed: AccentSeed (preset | custom)
    ─ lightTheme / darkTheme: ThemeData (派生)
    ↓ AnimatedBuilder 监听
MaterialApp.router
    theme: ctrl.lightTheme
    darkTheme: ctrl.darkTheme
    themeMode: ctrl.mode
    ↓
ThemeData.extensions += AppTokens
    ↓
Widget 中:context.tokens.bg / .ink / .accent ...
    (颜色切换时由 Material 自动做插值动画)
```

**新增/重构文件清单:**

| 路径 | 类型 | 作用 |
|---|---|---|
| `lib/theme/app_tokens.dart` | 新增 | `AppTokens extends ThemeExtension<AppTokens>` + `context.tokens` extension |
| `lib/theme/accent_palette.dart` | 新增 | 预设色定义 + 自定义色派生算法 + 对比度兜底 |
| `lib/theme/theme_controller.dart` | 新增 | `ChangeNotifier` 持有 mode + seed,产出 `ThemeData` |
| `lib/features/settings/appearance_settings_screen.dart` | 新增 | 外观设置页 UI |
| `lib/theme/theme.dart` | 重构 | `buildAppTheme(Brightness, AccentSeed) → ThemeData`,挂入 tokens |
| `lib/theme/tokens.dart` | 重构 | 删除 `T` 静态类,只保留色板常量供新 token 引用 |
| `lib/services/local_storage.dart` | 增量 | 新增 `themeMode` / `themeSeed` 读写 |
| `lib/app.dart` | 改造 | `MaterialApp` 接 `ThemeController` |
| `lib/routes.dart` | 增量 | 新增 `/settings/appearance` 路由 |
| `lib/features/settings/settings_screen.dart` | 增量 | 新增「外观」入口 row |
| 全局 30+ 文件 | 机械替换 | `T.x` → `context.tokens.x` |
| `pubspec.yaml` | 增量 | 增加 `flutter_colorpicker` 依赖 |

## 四、浅色主题色板设计

设计方向:**温暖、克制、专业**。不用纯白纯黑,避免廉价感。

### 4.1 表面与文字

| Token | 深色(现有,微调) | 浅色(新增) | 说明 |
|---|---|---|---|
| `bg` | `#000000` | `#FAF8F5` | 浅色用极淡暖米底,降低纯白刺眼感 |
| `elev1` | `#0E0E10` | `#FFFFFF` | 卡片层用纯白拉开层次 |
| `elev2` | `#16161A` | `#F2EFEA` | 二级卡片 / 输入框背景 |
| `elev3` | `#1F1F25` | `#E8E4DD` | 三级元素(选中态、悬浮) |
| `divider` | `#2A2A30` | `#E2DDD3` | 分隔线 |
| `ink` | `#FFFFFF` | `#1A1816` | 主文字,浅色用近黑暖灰 |
| `inkSub` | `#A8A8B0` | `#5C5852` | 副文字 |
| `inkDim` | `#6E6E78` | `#8A857E` | 弱化文字 |
| `inkMute` | `#3F3F47` | `#B8B2A8` | 占位 / 禁用 |

### 4.2 状态色(浅 / 深通用,保持品牌识别)

| Token | 深色 | 浅色 |
|---|---|---|
| `success` | `#00FF85` | `#00A864` |
| `warning` | `#FF8A3D` | `#E25A0A` |
| `danger` | `#FF3D5A` | `#D32647` |
| `info` | `#00E5FF` | `#0090A8` |

> 注:状态色与默认强调色重叠,因为它们都派生自同一品牌色板。

## 五、主题色系统

### 5.1 数据模型

```dart
sealed class AccentSeed {
  const AccentSeed();
  String serialize(); // 持久化字符串
  static AccentSeed parse(String s); // 反序列化
}

class PresetAccentSeed extends AccentSeed {
  final PresetAccent preset;
  // serialize: "preset:green"
}

class CustomAccentSeed extends AccentSeed {
  final int colorValue; // ARGB int
  // serialize: "custom:0xFF7A3DEC"
}

enum PresetAccent { green, orange, cyan, red }
```

### 5.2 预设色(默认值含双套)

预设色的 `accentInk` 是**手工调过**的(出于品牌一致性和视觉偏好),不走 5.3 的算法。

| 名称 | 深色模式 `accent` | 深色 `accentInk` | 浅色 `accent` | 浅色 `accentInk` |
|---|---|---|---|---|
| 经典绿(默认) | `#00FF85` | `#000000` | `#00A864` | `#FFFFFF` |
| 活力橙 | `#FF8A3D` | `#000000` | `#E25A0A` | `#FFFFFF` |
| 海洋青 | `#00E5FF` | `#000000` | `#0090A8` | `#FFFFFF` |
| 热情红 | `#FF3D5A` | `#FFFFFF` | `#D32647` | `#FFFFFF` |

### 5.3 自定义色派生算法

输入:用户选择的 `Color base`,目标 `Brightness mode`

```
1. 把 base 转 HSL
2. 若 mode == dark:
     L_target = max(L, 0.60)  // 提亮
     S_target = max(S, 0.70)  // 提饱和
3. 若 mode == light:
     L_target = min(L, 0.45)  // 降亮
     S_target = min(S, 0.80)  // 降饱和(过饱和的浅色刺眼)
4. derived = HSL(H, S_target, L_target).toColor()
5. 对比度兜底循环(最多 8 次):
     bgRef = (mode == dark ? #000000 : #FAF8F5)
     while contrastRatio(derived, bgRef) < 3.0:
       L_target += (mode == dark ? +0.05 : -0.05)
       L_target = clamp(L_target, 0, 1)
       derived = HSL(H, S_target, L_target).toColor()
       if L_target == 0 || L_target == 1: break
6. accentInk = relativeLuminance(derived) > 0.5 ? #000000 : #FFFFFF
7. 返回 (derived, accentInk)
```

**Why 3.0 而非 4.5:**WCAG AA 的 4.5 是正文小字标准;强调色主要用于按钮、tab、icon 等大尺寸 UI 元素,适用 AA Large 标准 3.0。

### 5.4 取色器

依赖 `flutter_colorpicker: ^1.1.0`(轻量、维护活跃)。

UI:`MaterialPicker`(材料色板)或 `BlockPicker`(色块网格),选择简单不容易选出极端色。底部确认按钮触发持久化。

## 六、ThemeController 设计

```dart
final themeController = ThemeController._();

class ThemeController extends ChangeNotifier {
  ThemeController._();

  ThemeMode _mode = ThemeMode.system;
  AccentSeed _seed = const PresetAccentSeed(PresetAccent.green);

  ThemeMode get mode => _mode;
  AccentSeed get seed => _seed;

  Future<void> load() async {
    _mode = LocalStore.themeMode;
    _seed = LocalStore.themeSeed;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode m) async {
    if (_mode == m) return;
    _mode = m;
    await LocalStore.setThemeMode(m);
    notifyListeners();
  }

  Future<void> setSeed(AccentSeed s) async {
    if (_seed == s) return;
    _seed = s;
    await LocalStore.setThemeSeed(s);
    notifyListeners();
  }

  ThemeData get lightTheme => buildAppTheme(Brightness.light, _seed);
  ThemeData get darkTheme  => buildAppTheme(Brightness.dark,  _seed);
}

final themeControllerProvider =
    ChangeNotifierProvider<ThemeController>((_) => themeController);
```

## 七、AppTokens(ThemeExtension)

```dart
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  final Color bg, elev1, elev2, elev3, divider;
  final Color ink, inkSub, inkDim, inkMute;
  final Color accent, accentInk;
  final Color success, warning, danger, info;
  // 间距 / 圆角等非颜色 token 也一并迁过来
  final double s1, s2, s3, s4, s5;
  final double r1, r2, r3, r4;

  const AppTokens({...});

  @override
  AppTokens copyWith({...}) => AppTokens(...);

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      // ... 其余颜色 token 也用 Color.lerp
      // 非颜色 token 用 lerpDouble 或直接取 other
    );
  }

  static AppTokens light(AccentSeed seed) { /* 构造浅色 */ }
  static AppTokens dark(AccentSeed seed)  { /* 构造深色 */ }
}

extension TokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
```

## 八、ThemeData 构造

```dart
ThemeData buildAppTheme(Brightness brightness, AccentSeed seed) {
  final tokens = brightness == Brightness.light
      ? AppTokens.light(seed)
      : AppTokens.dark(seed);

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: tokens.accent,
    onPrimary: tokens.accentInk,
    surface: tokens.elev1,
    onSurface: tokens.ink,
    background: tokens.bg,
    onBackground: tokens.ink,
    error: tokens.danger,
    onError: tokens.accentInk,
    // ... 其他 ColorScheme 字段从 tokens 派生
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: tokens.bg,
    extensions: [tokens],
    // ... 其他 ThemeData 字段(AppBarTheme 等)从 tokens 派生
  );
}
```

## 九、外观设置页 UI

**入口:** `lib/features/settings/settings_screen.dart` 顶部新增一个 row

```
🎨 外观           >
```

跳转 `/settings/appearance`

**页面结构:**

```
┌─ AppBar: 外观 ─┐
│
│ ── 主题模式 ──
│  ◉ 跟随系统      <- RadioListTile
│  ○ 浅色
│  ○ 深色
│
│ ── 主题色 ──
│  [● 绿] [● 橙] [● 青] [● 红] [⊕ 自定义]
│        当前选中色高亮 + ✓ 标记
│
│ ── 预览 ──
│  ┌────────────────────────────┐
│  │ 球局示例卡片                │
│  │ "周三晚 7:30  五人足球"     │
│  │ [立即报名]   主按钮          │
│  └────────────────────────────┘
│
└────────────────┘
```

- 即选即生效,无保存按钮(参考语言切换的体验)
- 自定义入口点击弹出 `flutter_colorpicker` 对话框,确认后保存
- 预览卡片实时反映当前主题
- 文案默认中文(本 App 主语言),通过 `intl` 提供英文翻译

**i18n 新增 key(`app_zh.arb` / `app_en.arb`):**

| key | 中 | 英 |
|---|---|---|
| `settings_appearance` | 外观 | Appearance |
| `appearance_theme_mode` | 主题模式 | Theme Mode |
| `appearance_theme_mode_system` | 跟随系统 | Follow System |
| `appearance_theme_mode_light` | 浅色 | Light |
| `appearance_theme_mode_dark` | 深色 | Dark |
| `appearance_accent_color` | 主题色 | Accent Color |
| `appearance_accent_green` | 经典绿 | Classic Green |
| `appearance_accent_orange` | 活力橙 | Vibrant Orange |
| `appearance_accent_cyan` | 海洋青 | Ocean Cyan |
| `appearance_accent_red` | 热情红 | Passion Red |
| `appearance_accent_custom` | 自定义 | Custom |
| `appearance_preview` | 预览 | Preview |
| `appearance_picker_title` | 选择主题色 | Pick Accent Color |
| `appearance_picker_confirm` | 确定 | Confirm |
| `appearance_picker_cancel` | 取消 | Cancel |

## 十、LocalStore 新增

```dart
// 在 lib/services/local_storage.dart 中

const _kThemeMode = 'theme_mode';
const _kThemeSeed = 'theme_seed';

class LocalStore {
  // ...

  static ThemeMode get themeMode {
    final raw = _prefs.getString(_kThemeMode) ?? 'system';
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark'  => ThemeMode.dark,
      _       => ThemeMode.system,
    };
  }

  static Future<void> setThemeMode(ThemeMode m) async {
    final raw = switch (m) {
      ThemeMode.light  => 'light',
      ThemeMode.dark   => 'dark',
      ThemeMode.system => 'system',
    };
    await _prefs.setString(_kThemeMode, raw);
  }

  static AccentSeed get themeSeed {
    final raw = _prefs.getString(_kThemeSeed) ?? 'preset:green';
    return AccentSeed.parse(raw);
  }

  static Future<void> setThemeSeed(AccentSeed s) async {
    await _prefs.setString(_kThemeSeed, s.serialize());
  }
}
```

## 十一、迁移策略(分两阶段降低风险)

### 阶段 A — 兼容层先建好(可单独 PR / commit)

1. 新增 `app_tokens.dart` + `accent_palette.dart`
2. 新增 `theme_controller.dart`(暂未接入 app)
3. 重构 `buildAppTheme(Brightness, AccentSeed)`,在 `ThemeData.extensions` 里挂上 tokens
4. **保留 `T` 类静态字段不动**,继续工作 — 项目能正常编译运行
5. `app.dart` 接入 `ThemeController`,把 `theme/darkTheme/themeMode` 都接好
6. 此时新外观设置页可以提前实装,主题模式切换已能生效。**视觉表现:**
   - Material 内置组件(`AppBar`、`Switch`、原生 `Button`、`BottomNavigationBar` 等)会跟随 `themeMode` 立即切换深 / 浅 → 用户能看到部分变化
   - 但所有引用了 `T.x` 静态颜色的自定义 widget(目前是绝大多数页面)仍然渲染成深色 → 看上去会有不一致
   - 所以阶段 A 不应单独发布,只用于本地验证基础设施可用
7. **commit ①**:基础设施就位(本地分支,不发布)

### 阶段 B — 机械替换 + 删除旧 T 类

8. 用 `sed`/`grep` 脚本批量替换:
   - `T\.bg\b` → `context.tokens.bg`
   - `T\.elev1\b` → `context.tokens.elev1`
   - …(每个 token 一次,共约 15-20 个 token)
9. 逐个 feature 目录手动 review:
   - `const` widget 中的 token 引用,需去掉外层 `const`(Flutter 自动复用,性能影响可忽略)
   - 静态 `BoxDecoration` / `TextStyle` 常量需改成方法形式接收 `BuildContext`
   - 列表 / 适配器中可能有 `final color = T.x` 的中间变量,改成在 build 时取 `context.tokens.x`
10. 全部替换完毕后删除 `tokens.dart` 中的 `T` 类(保留预设色板常量供 `app_tokens.dart` 引用)
11. 浅 / 深切换 + 主题色配置正式生效
12. **commit ②**:迁移完成 → 此时整体功能完整,可发布 PR

### 风险点与对策

| 风险 | 对策 |
|---|---|
| `const` widget 失去 const 优化 | 影响极小,Flutter 复用常量 widget 有其他机制;且大多 token 引用在 build 内,不在 const ctx |
| 个别 token 在 model / service 层被使用 | 这类不该用 token,review 时改为传入或常量 |
| Golden test(若有)会全量失效 | 重新生成 light + dark 双套 golden |
| 热重载 / 热重启时 ThemeController 状态丢失 | 在 `main()` 中 `await themeController.load()` 后再 runApp |

## 十二、测试

### 12.1 单元测试

- `accent_palette_test.dart`:
  - 4 个预设色每个都返回正确的 `(accent, accentInk)` 对
  - `derive(custom, mode)` 对 30 组随机颜色,与对应 `bg` 对比度 ≥ 3.0
  - 极端输入(纯白、纯黑、灰)派生后仍可读

- `theme_controller_test.dart`:
  - `setMode` / `setSeed` 触发 `notifyListeners` 且写入 LocalStore
  - `load()` 正确反序列化各种 seed 字符串

### 12.2 Widget 测试

- `appearance_settings_screen_test.dart`:
  - 三个模式 RadioListTile 的选择能反映到 `themeController.mode`
  - 点击预设色 chip 能反映到 `themeController.seed`
  - 自定义入口能弹出取色器(可只测能否打开 dialog)

- `theme_extension_test.dart`:
  - 在浅 / 深主题下,`context.tokens.bg` / `accent` 取到对应模式的值

### 12.3 手测 checklist

- [ ] 三种模式切换,所有底部 tab 页面立即变色,无白屏 / 闪烁
- [ ] 切换有平滑动画(由 `ThemeData.lerp` 自动提供)
- [ ] 主题色变化对所有按钮 / tab 选中态 / 进度条 / icon 同步生效
- [ ] 自定义颜色取色后,深色和浅色模式下都可读(不刺眼、文字够清晰)
- [ ] 杀进程冷启动后,主题模式 + 主题色保持上次选择
- [ ] iOS 系统切换深 / 浅时,`themeMode == system` 状态下 App 跟随
- [ ] 中英文文案都正确显示

## 十三、未来扩展(本期不做但留位)

- 字体大小 / 显示密度
- 动效开关(disable animations for accessibility)
- 紧凑模式 / 舒适模式
- 高对比度模式(无障碍)
- 主题色对默认头像 / 占位插图的次级染色

这些都可以放进同一个「外观」二级页,不影响本期架构。
