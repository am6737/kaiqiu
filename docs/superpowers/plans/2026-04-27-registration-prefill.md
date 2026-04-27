# Registration Form Pre-fill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pre-fill the event registration form with the current user's name and phone number from their profile.

**Architecture:** Add a `phone` column to the `profiles` table. Expose it in the `Profile` model and profile edit screen. Read the current user's profile when opening the registration bottom sheet and set the contact/phone controllers before the sheet renders.

**Tech Stack:** Flutter, Riverpod, Supabase (Postgres migration), ARB localization

---

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `supabase/migrations/0016_profile_phone.sql` | DB migration: add `phone` column |
| Modify | `lib/models/profile.dart` | Add `phone` field to model |
| Modify | `lib/l10n/app_zh.arb` | Add `profile_edit_phone` Chinese string |
| Modify | `lib/l10n/app_en.arb` | Add `profile_edit_phone` English string |
| Modify | `lib/l10n/generated/app_localizations.dart` | Add abstract getter |
| Modify | `lib/l10n/generated/app_localizations_zh.dart` | Add Chinese implementation |
| Modify | `lib/l10n/generated/app_localizations_en.dart` | Add English implementation |
| Modify | `lib/features/profile/profile_edit_screen.dart` | Add phone field to edit form |
| Modify | `lib/features/events/widgets/bottom_cta.dart` | Pre-fill contact & phone from profile |

---

### Task 1: Supabase Migration

**Files:**
- Create: `supabase/migrations/0016_profile_phone.sql`

- [ ] **Step 1: Create migration file**

```sql
ALTER TABLE profiles ADD COLUMN phone text;
```

Write this single line to `supabase/migrations/0016_profile_phone.sql`.

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/0016_profile_phone.sql
git commit -m "feat(db): add phone column to profiles table"
```

---

### Task 2: Profile Model

**Files:**
- Modify: `lib/models/profile.dart`

- [ ] **Step 1: Add `phone` field to `Profile` class**

In `lib/models/profile.dart`, add `final String? phone;` after the `district` field (line 7). Add `this.phone,` to the constructor after `this.district,`. Add `phone: m['phone'] as String?,` to `fromMap` after the `district` line. Add `'phone': phone,` to `toMap` after the `district` line.

The full updated file should be:

```dart
// profile.dart — corresponds to Supabase profiles table
class Profile {
  final String id;
  final String name;
  final String? handle;
  final String? city;
  final String? district;
  final String? phone;
  final String? position;
  final int? height;
  final String? foot;
  final String? avatarUrl;
  final String? bannerUrl;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.name,
    this.handle,
    this.city,
    this.district,
    this.phone,
    this.position,
    this.height,
    this.foot,
    this.avatarUrl,
    this.bannerUrl,
    required this.createdAt,
  });

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
    id: m['id'] as String,
    name: m['name'] as String,
    handle: m['handle'] as String?,
    city: m['city'] as String?,
    district: m['district'] as String?,
    phone: m['phone'] as String?,
    position: m['position'] as String?,
    height: m['height'] as int?,
    foot: m['foot'] as String?,
    avatarUrl: m['avatar_url'] as String?,
    bannerUrl: m['banner_url'] as String?,
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'handle': handle,
    'city': city,
    'district': district,
    'phone': phone,
    'position': position,
    'height': height,
    'foot': foot,
    'avatar_url': avatarUrl,
    'banner_url': bannerUrl,
  };
}
```

- [ ] **Step 2: Verify build**

Run: `flutter analyze lib/models/profile.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/models/profile.dart
git commit -m "feat(model): add phone field to Profile"
```

---

### Task 3: Localization Strings

**Files:**
- Modify: `lib/l10n/app_zh.arb` (line 530, after `profile_edit_district`)
- Modify: `lib/l10n/app_en.arb` (line 530, after `profile_edit_district`)
- Modify: `lib/l10n/generated/app_localizations.dart` (after `profile_edit_district` getter, around line 2654)
- Modify: `lib/l10n/generated/app_localizations_zh.dart` (after `profile_edit_district` getter, around line 1347)
- Modify: `lib/l10n/generated/app_localizations_en.dart` (after `profile_edit_district` getter, around line 1362)

- [ ] **Step 1: Add ARB entries**

In `lib/l10n/app_zh.arb`, after the `"profile_edit_district": "城区",` line, add:

```
  "profile_edit_phone": "手机号",
```

In `lib/l10n/app_en.arb`, after the `"profile_edit_district": "District",` line, add:

```
  "profile_edit_phone": "Phone",
```

- [ ] **Step 2: Add abstract getter to `app_localizations.dart`**

In `lib/l10n/generated/app_localizations.dart`, after the `profile_edit_district` getter block (around line 2654), add:

```dart
  /// No description provided for @profile_edit_phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get profile_edit_phone;
```

- [ ] **Step 3: Add Chinese implementation**

In `lib/l10n/generated/app_localizations_zh.dart`, after the line `String get profile_edit_district => '城区';` (around line 1347), add:

```dart
  @override
  String get profile_edit_phone => '手机号';
```

- [ ] **Step 4: Add English implementation**

In `lib/l10n/generated/app_localizations_en.dart`, after the line `String get profile_edit_district => 'District';` (around line 1362), add:

```dart
  @override
  String get profile_edit_phone => 'Phone';
```

- [ ] **Step 5: Verify build**

Run: `flutter analyze lib/l10n/`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/
git commit -m "feat(l10n): add profile_edit_phone string"
```

---

### Task 4: Profile Edit Screen — Phone Field

**Files:**
- Modify: `lib/features/profile/profile_edit_screen.dart`

- [ ] **Step 1: Add `_phone` controller**

In `_ProfileEditScreenState`, after the `_district` controller declaration (line 29), add:

```dart
  final _phone = TextEditingController();
```

- [ ] **Step 2: Load phone in `_load()`**

In the `_load()` method, after `_district.text = p?.district ?? '';` (line 56), add:

```dart
      _phone.text = p?.phone ?? '';
```

- [ ] **Step 3: Dispose `_phone`**

In `dispose()`, after `_district.dispose();` (line 130), add:

```dart
    _phone.dispose();
```

- [ ] **Step 4: Add phone to save payload**

In `_save()`, inside the `update()` call's map (around line 142-152), after the `'district'` entry, add:

```dart
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
```

- [ ] **Step 5: Add phone input field to UI**

In the `build()` method's `ListView` children, after the `_Field` for district (line 199) and before the `_Field` for height (line 200), add:

```dart
                        _Field(
                          label: l.profile_edit_phone,
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                        ),
```

- [ ] **Step 6: Verify build**

Run: `flutter analyze lib/features/profile/profile_edit_screen.dart`
Expected: No issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/profile/profile_edit_screen.dart
git commit -m "feat(profile): add phone field to profile edit screen"
```

---

### Task 5: Registration Form Pre-fill

**Files:**
- Modify: `lib/features/events/widgets/bottom_cta.dart`

- [ ] **Step 1: Pre-fill contact and phone controllers**

In `showRegisterSheet()`, after the four `TextEditingController` declarations (lines 189-192) and before `membersNotifier` (line 193), add these lines to read the current user's profile and pre-fill:

```dart
    final profile = ref.read(myProfileProvider).valueOrNull;
    contactC.text = profile?.name ?? '';
    phoneC.text = profile?.profile.phone ?? '';
```

This uses the already-cached `myProfileProvider` (a `FutureProvider<PlayerProfile?>`) which is watched on the profile screen and throughout the app. `ref.read(...).valueOrNull` gives the synchronous cached value — no `await` needed. If the profile hasn't loaded yet (unlikely since the user navigated through the app), the fields remain empty and the user fills them manually.

`profile?.name` is the convenience getter on `PlayerProfile` that returns `profile.profile.name`.
`profile?.profile.phone` accesses the `phone` field on the underlying `Profile` object.

- [ ] **Step 2: Verify build**

Run: `flutter analyze lib/features/events/widgets/bottom_cta.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/events/widgets/bottom_cta.dart
git commit -m "feat(registration): pre-fill contact and phone from user profile"
```

---

### Task 6: Manual Verification

- [ ] **Step 1: Test profile edit flow**

1. Run the app (`flutter run -d chrome`)
2. Go to profile → edit profile
3. Verify the phone field appears between district and height
4. Enter a phone number, save
5. Re-open edit screen — verify phone number persisted

- [ ] **Step 2: Test registration pre-fill flow**

1. Navigate to an event that is in registration status
2. Tap the register button
3. Verify the contact field is pre-filled with your profile name
4. Verify the phone field is pre-filled with your profile phone number
5. Modify both fields, submit the registration
6. Verify the registration succeeds
7. Check that your profile phone number was NOT changed (open edit profile to confirm)
