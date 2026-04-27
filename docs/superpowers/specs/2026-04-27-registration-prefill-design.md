# Registration Form Pre-fill with Current User Info

## Problem

报名参赛表单的联系人和手机号需要手动输入，没有利用已有的用户信息。用户每次报名都要重复填写相同内容。

## Decision

- profiles 表新增 `phone` 字段
- 个人资料编辑页新增手机号编辑入口
- 报名表单打开时自动回填当前用户的姓名和手机号
- 表单中的修改仅用于当次报名，不回写 profiles

## Design

### 1. 数据层

**Supabase migration** (`0016_profile_phone.sql`):

```sql
ALTER TABLE profiles ADD COLUMN phone text;
```

**Profile model** (`lib/models/profile.dart`):

- 新增 `final String? phone;` 字段
- `fromMap`: 读取 `m['phone'] as String?`
- `toMap`: 写入 `'phone': phone`
- 构造函数新增 `this.phone` 可选参数

### 2. 个人资料编辑页

**文件**: `lib/features/profile/profile_edit_screen.dart`

变更:
- 新增 `_phone` TextEditingController
- `_load()`: `_phone.text = p?.phone ?? ''`
- `_save()`: payload 中增加 `'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim()`
- `dispose()`: dispose `_phone`
- UI: 在 district 和 height 之间插入手机号输入字段，keyboardType 为 `TextInputType.phone`

### 3. 报名表单回填

**文件**: `lib/features/events/widgets/bottom_cta.dart`

变更:
- `showRegisterSheet` 方法开头，在创建 TextEditingController 后，读取当前用户 Profile
- `contactC.text = profile.name`
- `phoneC.text = profile.phone ?? ''`
- 用户可自由修改这两个字段
- 提交逻辑不变，仍然只写入 teams 表

### 4. 本地化

新增 key: `profile_edit_phone`
- 中文: `手机号`
- 英文: `Phone`

### 5. 不涉及的变更

- `PlayerProfile` 模型不需要改（它聚合 `Profile`，自动获得 phone）
- teams 表结构不变
- 报名提交逻辑不变
- 手机号无额外格式校验（报名表单已有 phone validation）
