# Contributing to 开球 · GameOn

**中文** · [English](CONTRIBUTING.en.md)

欢迎贡献。本文档是给**内部团队成员**和**社区贡献者**的协作指南。

项目概况、技术栈、目录结构、运行方式见 [README.md](README.md)。本文档只讲"怎么协作"。

## 核心原则

- **小步提交** —— 一个 PR 解决一件事，便于 review 和回滚
- **测试先行** —— 改逻辑层 (`services/` / `repositories/` / `models/`) 必须写/更新测试
- **设计先行** —— 新 feature / 影响 >3 个文件的重构，先写 spec
- **读 RLS** —— 任何数据库读写改动前，先确认对应表的 Row Level Security 策略

## 开发流程

### 1. 获取最新主干

```bash
git checkout main
git pull --rebase
```

### 2. 建 feature 分支

命名规则：`<type>/<short-description>`

| type | 用途 | 例 |
|---|---|---|
| `feat/` | 新功能 | `feat/pickup-rating` |
| `fix/` | Bug 修复 | `fix/crash-on-empty-pickup` |
| `refactor/` | 重构（不改行为） | `refactor/extract-supabase-client` |
| `docs/` | 文档 | `docs/contributing` |
| `chore/` | 杂项（依赖、CI） | `chore/bump-flutter-3.42` |
| `test/` | 只加测试 | `test/rating-repo` |

```bash
git checkout -b feat/pickup-rating
```

### 3. 写代码 + 测试

- `flutter analyze` 必须通过 (CI 会挡)
- `flutter test` 必须通过
- 改 UI 的，自己在模拟器上手动过一遍主流程 + 边界情况

### 4. 本地自检

提交前本地跑一遍，节省 CI 时间：

```bash
flutter analyze
flutter test
dart format lib/ test/     # 格式化 + 检查 diff
```

### 5. 提交

**Commit message 格式**（参考 Conventional Commits）：

```
<type>: <短描述，祈使语气，首字母小写>

<可选：段落解释 why，不解释 what>
<可选：相关 issue / 决策文档路径>
```

**Type 列表**：

| type | 含义 |
|---|---|
| `feat` | 新功能（面向用户） |
| `fix` | Bug 修复 |
| `refactor` | 重构（不改行为） |
| `perf` | 性能优化 |
| `docs` | 只改文档 |
| `test` | 只改/加测试 |
| `chore` | 依赖升级、CI、工具配置 |
| `style` | 格式化（几乎不单独用） |

**好例**：
```
feat: add Elo-based rating calculation to pickup matches

Uses K-factor = 24 for casual matches. Separate from event matches
(K = 32). Wiring for event matches lands in follow-up PR.

Design: docs/superpowers/specs/2026-04-20-rating-design.md
```

**坏例**：
```
update code                ← 没有 type、不说 what
fixed bug                   ← 哪个 bug？
WIP                         ← 别 push WIP commit 到主干
```

### 6. 开 PR

```bash
git push -u origin feat/pickup-rating
gh pr create --fill
```

PR 描述模板（建议）：

```markdown
## What
<一句话：这个 PR 做了啥>

## Why
<为什么要做 / 解决什么问题>

## How
<关键实现思路，2-3 句>

## Test plan
- [ ] flutter analyze pass
- [ ] flutter test pass
- [ ] 手工验证：[主流程 / 边界]
- [ ] （如果涉及）Supabase migrations 在本地项目跑过
```

### 7. Code Review

- 被 review 的人：**别 force-push 覆盖历史**（让 reviewer 能看增量 diff）
- Review 通过后 merge 前可以 squash 或整理 commits
- 大 PR (>500 行) 优先拆分；确实拆不了请在描述里解释

## 代码风格

Flutter / Dart 官方默认，项目没魔改规则（见 [`analysis_options.yaml`](analysis_options.yaml) 只 include 了 `flutter_lints`）。

几个约定（非强制但 review 时会提）：

- **单引号优先** —— 字符串默认 `'...'`，除非需要插值 `$` 或包含 `'`
- **trailing commas** —— 多参数构造器末尾留逗号（dartfmt 会自动换行、diff 更干净）
- **const 能用就用** —— widget 构造优先加 `const`
- **文件顶部一行注释说明作用** —— `// foo.dart — short purpose`（非 docstring，只一行）
- **不写冗余注释** —— 命名自解释就别写 `// get user profile` 这种
- **避免抽象先行** —— 三个重复不算重复，等出现第四个再抽基类 / mixin

## 项目架构（速览）

```
lib/features/<name>/           # 功能模块（一个 feature 一个目录）
     └── *_screen.dart         # 页面 widget
     └── <name>_providers.dart # Riverpod state（如有）

lib/repositories/              # Supabase 读写封装（薄一层，映射 model）
lib/services/supabase.dart     # Supabase client 单例 + helper
lib/models/                    # 纯数据类（freezed / 手写）
lib/widgets/                   # 跨 feature 的共享组件
lib/data/mock.dart             # 脚手架阶段的离线 mock
```

**分层原则**：
- Screen 只管 UI + Riverpod 订阅
- Providers 编排 repository 调用 + 状态转换
- Repository 是 Supabase SDK 的薄封装，**不能**在 screen 里直接调 `Supabase.instance`
- Model 是纯数据，不依赖 Flutter

## 数据库迁移

改 schema 要走 migration，**禁止**直接在 Supabase 面板 SQL Editor 手动改生产。

### 新增一个 migration

1. 在 `supabase/migrations/` 建新文件，命名 `NNNN_short_description.sql`
   （`NNNN` 顺序递增，看当前最大编号 +1）
2. 文件开头写注释说明动机、RLS 影响、向后兼容性
3. SQL 里**必须**包含新表的 RLS 策略（我们默认所有表启用 RLS）
4. 本地先在 Supabase 测试项目跑通，再进 PR
5. PR 合并 + 生产部署时，需要有人手动在生产 SQL Editor 里执行（目前未自动化）

### Seed 数据

`supabase/seed/` 下是 demo 数据，只在**新建环境**时跑一次。
不要往 seed 里加会冲突的 `INSERT`（用 `ON CONFLICT DO NOTHING` 保护）。

## 设计文档 / Spec

任何满足以下条件的改动，先写 spec 再写代码：

- 影响 3 个以上文件的重构
- 新 feature（即使只有一个 screen）
- 会改数据模型的功能
- 外部依赖引入（新 package、新第三方服务）

存放位置：`docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`

格式参考已有的 [2026-04-20-rebrand-kaiqiu-gameon-design.md](docs/superpowers/specs/2026-04-20-rebrand-kaiqiu-gameon-design.md)：决定 + 理由 + 改动清单 + 保留项 + out-of-scope。

## Secrets / 敏感信息

**永远不提交**：

- `.env` / `.env.local`
- `lib/config/env.local.dart`（已 gitignore）
- Android keystore / iOS provisioning profile / Supabase service_role key

**可提交**（Supabase anon key 除外的其他情况按下述）：

- Supabase **anon key** 设计为客户端分发，可入库；但建议在 release 构建时改走 `--dart-define`，不把 key 编译进默认值
- Bundle ID、应用包名、API URL（非 secret）

CI 用到的 secrets 配在 GitHub 仓库 / org 的 **Settings → Secrets and variables → Actions**。

## 测试

当前只有 `test/widget_test.dart` 一个 smoke test。补充测试的优先级：

1. **Repository 层** —— 对着 Supabase 本地 mock 或 `fake_supabase` 写集成测试
2. **Provider 层** —— Riverpod `container.read` + mock repository
3. **Widget 层** —— 只对复杂 widget（带状态 / 计算）写，简单展示组件不写

运行：

```bash
flutter test                   # 全部
flutter test test/foo_test.dart  # 单文件
flutter test --coverage       # 带覆盖率
```

## 常见问题

### 我改了 `pubspec.yaml`，PR 需要带 `pubspec.lock` 吗？

**带**。Flutter 项目 `pubspec.lock` 是要提交的（不同于 library 包），保证 CI 和其他人装的是同一套版本。

### CI 失败但本地通过？

常见原因：

- 环境差异（Flutter 版本、Xcode 版本）—— 看 CI log 最上面的版本号
- 本地有未提交文件（格式化 / `.gitignore` 覆盖）—— `git status` 检查
- macOS runner pod cache miss —— rerun 一般就好

贴出 CI 链接 + 错误段，比描述快 10 倍。

### 想加一个 feature，但不确定要不要做？

**先开 issue 讨论**，不要先动手。小 feature（30 分钟以内）可以直接 PR，标题写 `rfc:`。

## 问题反馈

- Bug / feature 请求：GitHub Issues
- 安全问题（含 RLS 绕过）：**不要**发 issue，邮件发给 owner 私下处理

---

如果本文档有不清楚或过时的地方，欢迎直接 PR 修正。
