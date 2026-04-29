# Event & Pickup In-App Notifications — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically create in-app notification records when key event/pickup actions occur, using PostgreSQL triggers.

**Architecture:** A single new migration file adds a `notify()` helper function, 5 trigger functions, and 6 triggers on `teams`, `individual_registrations`, `events`, `matches`, and `pickup_slots` tables. All functions use `security definer` to bypass RLS when inserting into the `notifications` table. No frontend or model changes needed.

**Tech Stack:** PostgreSQL / PL/pgSQL (Supabase migration)

**Spec correction:** The spec uses `/events/{event_id}` as the notification route, but the actual Go Router path is `/event/:id` (singular). All triggers will use `/event/{id}` for event notifications and `/pickup/{id}` for pickup notifications.

---

### Task 1: Create migration file with `notify()` helper function

**Files:**
- Create: `supabase/migrations/0002_notification_triggers.sql`

- [ ] **Step 1: Create the migration file with the helper function**

```sql
-- 0002_notification_triggers.sql
-- Auto-create in-app notifications via DB triggers.

-- ── Helper ──────────────────────────────────────────────
create or replace function public.notify(
  p_user_id uuid,
  p_type    text,
  p_title   text,
  p_body    text,
  p_icon    text,
  p_route   text
) returns void
  language plpgsql
  security definer
  set search_path = public
as $$
begin
  insert into notifications (user_id, type, title, body, icon, route)
  values (p_user_id, p_type, p_title, p_body, p_icon, p_route);
end;
$$;
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/0002_notification_triggers.sql
git commit -m "feat(notif): add notify() helper function in new migration"
```

---

### Task 2: Add team notification trigger (scenes 1-3)

Covers:
- Team registers for event → notify event creator
- Team approved → notify captain
- Team rejected → notify captain

**Files:**
- Modify: `supabase/migrations/0002_notification_triggers.sql`

- [ ] **Step 1: Append the trigger function and trigger**

Append to the end of `0002_notification_triggers.sql`:

```sql
-- ── Teams: registration + review ────────────────────────
create or replace function public.fn_notify_team_change()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_event   record;
  v_actor   uuid := auth.uid();
begin
  select id, name, creator_id
    into v_event
    from events
   where id = NEW.event_id;

  if TG_OP = 'INSERT' then
    -- Scene 1: team registered → notify event creator
    if v_event.creator_id is distinct from NEW.captain_id then
      perform notify(
        v_event.creator_id,
        'match',
        '有新队伍报名',
        NEW.name || ' 报名了你的赛事',
        'how_to_reg',
        '/event/' || v_event.id
      );
    end if;
  end if;

  if TG_OP = 'UPDATE' and OLD.status is distinct from NEW.status then
    if NEW.status = 'approved' then
      -- Scene 2: approved → notify captain
      perform notify(
        NEW.captain_id,
        'match',
        '队伍审核通过',
        '你的队伍 ' || NEW.name || ' 已通过审核',
        'check_circle',
        '/event/' || v_event.id
      );
    elsif NEW.status = 'rejected' then
      -- Scene 3: rejected → notify captain
      perform notify(
        NEW.captain_id,
        'match',
        '队伍未通过审核',
        '你的队伍 ' || NEW.name || ' 未通过审核',
        'cancel',
        '/event/' || v_event.id
      );
    end if;
  end if;

  return NEW;
end;
$$;

create trigger trg_notify_team_change
  after insert or update on public.teams
  for each row execute function public.fn_notify_team_change();
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/0002_notification_triggers.sql
git commit -m "feat(notif): add team registration/review notification trigger"
```

---

### Task 3: Add individual registration notification trigger (scenes 4-6)

Covers:
- Individual registers → notify event creator
- Individual assigned to team → notify the individual
- Individual rejected → notify the individual

**Files:**
- Modify: `supabase/migrations/0002_notification_triggers.sql`

- [ ] **Step 1: Append the trigger function and trigger**

Append to the end of `0002_notification_triggers.sql`:

```sql
-- ── Individual registrations ────────────────────────────
create or replace function public.fn_notify_individual_reg()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_event      record;
  v_team_name  text;
begin
  select id, name, creator_id
    into v_event
    from events
   where id = NEW.event_id;

  if TG_OP = 'INSERT' then
    -- Scene 4: individual registered → notify event creator
    if v_event.creator_id is distinct from NEW.user_id then
      perform notify(
        v_event.creator_id,
        'match',
        '有新个人报名',
        NEW.name || ' 报名了你的赛事',
        'how_to_reg',
        '/event/' || v_event.id
      );
    end if;
  end if;

  if TG_OP = 'UPDATE' and OLD.status is distinct from NEW.status then
    if NEW.status = 'assigned' then
      -- Scene 5: assigned to team → notify the individual
      select name into v_team_name from teams where id = NEW.assigned_team_id;
      perform notify(
        NEW.user_id,
        'match',
        '你已被分配到队伍',
        '你已被分配到 ' || coalesce(v_team_name, '未知队伍'),
        'check_circle',
        '/event/' || v_event.id
      );
    elsif NEW.status = 'rejected' then
      -- Scene 6: rejected → notify the individual
      perform notify(
        NEW.user_id,
        'match',
        '个人报名未通过',
        '你在赛事中的个人报名未通过审核',
        'cancel',
        '/event/' || v_event.id
      );
    end if;
  end if;

  return NEW;
end;
$$;

create trigger trg_notify_individual_reg
  after insert or update on public.individual_registrations
  for each row execute function public.fn_notify_individual_reg();
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/0002_notification_triggers.sql
git commit -m "feat(notif): add individual registration notification trigger"
```

---

### Task 4: Add event status notification trigger (scenes 7-8)

Covers:
- Event status → `ongoing` → notify all approved team members
- Event status → `completed` or `done` → notify all approved team members

**Files:**
- Modify: `supabase/migrations/0002_notification_triggers.sql`

- [ ] **Step 1: Append the trigger function and trigger**

Append to the end of `0002_notification_triggers.sql`:

```sql
-- ── Event status changes ────────────────────────────────
create or replace function public.fn_notify_event_status()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_actor  uuid := auth.uid();
  v_icon   text;
  v_title  text;
  v_body   text;
  v_member record;
begin
  if OLD.status is not distinct from NEW.status then
    return NEW;
  end if;

  if NEW.status = 'ongoing' then
    v_icon  := 'sports_soccer';
    v_title := '赛事已开赛';
    v_body  := NEW.name || ' 已正式开赛';
  elsif NEW.status in ('completed', 'done') then
    v_icon  := 'emoji_events';
    v_title := '赛事已结束';
    v_body  := NEW.name || ' 已结束';
  else
    return NEW;
  end if;

  for v_member in
    select distinct tm.user_id
      from team_members tm
      join teams t on t.id = tm.team_id
     where t.event_id = NEW.id
       and t.status = 'approved'
       and tm.user_id is distinct from v_actor
  loop
    perform notify(
      v_member.user_id,
      'match',
      v_title,
      v_body,
      v_icon,
      '/event/' || NEW.id
    );
  end loop;

  return NEW;
end;
$$;

create trigger trg_notify_event_status
  after update on public.events
  for each row execute function public.fn_notify_event_status();
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/0002_notification_triggers.sql
git commit -m "feat(notif): add event status change notification trigger"
```

---

### Task 5: Add match result notification trigger (scene 9)

Covers:
- Match `done` flips `false` → `true` → notify both teams' members

**Files:**
- Modify: `supabase/migrations/0002_notification_triggers.sql`

- [ ] **Step 1: Append the trigger function and trigger**

Append to the end of `0002_notification_triggers.sql`:

```sql
-- ── Match result ────────────────────────────────────────
create or replace function public.fn_notify_match_result()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_actor    uuid := auth.uid();
  v_event_id uuid;
  v_a_name   text;
  v_b_name   text;
  v_body     text;
  v_member   record;
begin
  if OLD.done = true or NEW.done is not true then
    return NEW;
  end if;

  v_event_id := NEW.event_id;

  select coalesce(t.name, NEW.team_a_label, '队伍A') into v_a_name
    from teams t where t.id = NEW.team_a_id;
  select coalesce(t.name, NEW.team_b_label, '队伍B') into v_b_name
    from teams t where t.id = NEW.team_b_id;

  v_body := v_a_name || ' ' || coalesce(NEW.score_a, 0)
          || ' - ' || coalesce(NEW.score_b, 0) || ' ' || v_b_name;

  for v_member in
    select distinct tm.user_id
      from team_members tm
      join teams t on t.id = tm.team_id
     where tm.team_id in (NEW.team_a_id, NEW.team_b_id)
       and t.status = 'approved'
       and tm.user_id is distinct from v_actor
  loop
    perform notify(
      v_member.user_id,
      'match',
      '比赛结果出炉',
      v_body,
      'emoji_events',
      '/event/' || v_event_id
    );
  end loop;

  return NEW;
end;
$$;

create trigger trg_notify_match_result
  after update on public.matches
  for each row execute function public.fn_notify_match_result();
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/0002_notification_triggers.sql
git commit -m "feat(notif): add match result notification trigger"
```

---

### Task 6: Add pickup slot join notification trigger (scenes 10-11)

Covers:
- Someone joins pickup → notify host
- Pickup becomes full → notify host (instead of the "join" notification)

**Files:**
- Modify: `supabase/migrations/0002_notification_triggers.sql`

- [ ] **Step 1: Append the trigger function and trigger**

Append to the end of `0002_notification_triggers.sql`:

```sql
-- ── Pickup slot join ────────────────────────────────────
create or replace function public.fn_notify_pickup_slot_join()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_pickup    record;
  v_user_name text;
  v_filled    int;
begin
  if NEW.user_id is null then
    return NEW;
  end if;
  if TG_OP = 'UPDATE' and OLD.user_id is not null then
    return NEW;
  end if;

  select id, host_id, total, title, venue
    into v_pickup
    from pickups
   where id = NEW.pickup_id;

  if NEW.user_id = v_pickup.host_id then
    return NEW;
  end if;

  select coalesce(p.name, '球友') into v_user_name
    from profiles p where p.id = NEW.user_id;

  select count(*) into v_filled
    from pickup_slots
   where pickup_id = NEW.pickup_id
     and user_id is not null;

  if v_filled >= v_pickup.total then
    -- Scene 11: full → send full notification instead of join
    perform notify(
      v_pickup.host_id,
      'pickup',
      '你的约球已满员',
      '你的约球已满员（' || v_pickup.total || '/' || v_pickup.total || '）',
      'check_circle',
      '/pickup/' || v_pickup.id
    );
  else
    -- Scene 10: someone joined
    perform notify(
      v_pickup.host_id,
      'pickup',
      '有人加入了你的约球',
      v_user_name || ' 加入了你的约球',
      'sports_soccer',
      '/pickup/' || v_pickup.id
    );
  end if;

  return NEW;
end;
$$;

create trigger trg_notify_pickup_slot_join
  after insert or update on public.pickup_slots
  for each row execute function public.fn_notify_pickup_slot_join();
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/0002_notification_triggers.sql
git commit -m "feat(notif): add pickup slot join/full notification trigger"
```

---

### Task 7: Add pickup slot leave notification trigger (scene 12)

Covers:
- Someone leaves pickup → notify host

**Files:**
- Modify: `supabase/migrations/0002_notification_triggers.sql`

- [ ] **Step 1: Append the trigger function and trigger**

Append to the end of `0002_notification_triggers.sql`:

```sql
-- ── Pickup slot leave ───────────────────────────────────
create or replace function public.fn_notify_pickup_slot_leave()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_host_id   uuid;
  v_user_name text;
begin
  if OLD.user_id is null then
    return OLD;
  end if;

  select host_id into v_host_id
    from pickups
   where id = OLD.pickup_id;

  if OLD.user_id = v_host_id then
    return OLD;
  end if;

  select coalesce(p.name, '球友') into v_user_name
    from profiles p where p.id = OLD.user_id;

  perform notify(
    v_host_id,
    'pickup',
    '有人退出了你的约球',
    v_user_name || ' 退出了你的约球',
    'logout',
    '/pickup/' || OLD.pickup_id
  );

  return OLD;
end;
$$;

create trigger trg_notify_pickup_slot_leave
  after delete on public.pickup_slots
  for each row execute function public.fn_notify_pickup_slot_leave();
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/0002_notification_triggers.sql
git commit -m "feat(notif): add pickup slot leave notification trigger"
```

---

### Task 8: Verify migration applies cleanly

**Files:**
- Read: `supabase/migrations/0002_notification_triggers.sql` (full file review)

- [ ] **Step 1: Reset and re-apply all migrations**

```bash
cd /home/coder/workspaces/qiuju_app && npx supabase db reset
```

Expected: migrations apply without errors. If `supabase` CLI is not available, verify by reading the full SQL file for syntax issues.

- [ ] **Step 2: Verify all triggers exist**

If Supabase CLI is available, connect to the local DB and run:

```sql
select tgname from pg_trigger where tgname like 'trg_notify%';
```

Expected output — 6 triggers:
- `trg_notify_team_change`
- `trg_notify_individual_reg`
- `trg_notify_event_status`
- `trg_notify_match_result`
- `trg_notify_pickup_slot_join`
- `trg_notify_pickup_slot_leave`

- [ ] **Step 3: Final commit**

```bash
git add supabase/migrations/0002_notification_triggers.sql
git commit -m "feat(notif): complete all notification triggers for events and pickups"
```
