-- hotfix_orphan_profiles.sql
--
-- 修复「打开赛事讨论 tab 报 conversation_members_user_id_fkey」的线上/开发库。
-- 直接整段 paste 进 Supabase Dashboard → SQL Editor 运行，幂等、安全、可重复。
--
-- 做三件事：
--   1) backfill 所有 auth.users 里存在但 profiles 里缺失的用户（含 ca8f5a43-...）
--   2) 把 handle_new_user trigger 改成幂等（on conflict do nothing）
--   3) 把 ensure_demo_conversation / ensure_event_conversation 两个 RPC
--      升级为「自愈」版本——开头先补齐当前用户的 profile 行
--
-- 这份脚本不碰业务表结构、不动 RLS 策略、不改任何客户端代码。


-- ─────────────────────────────────────────────────────────────
-- 1) 一次性 backfill：为所有孤儿 auth 用户补 profile
-- ─────────────────────────────────────────────────────────────
insert into public.profiles (id, name)
select
  u.id,
  coalesce(u.raw_user_meta_data->>'name', '新球友')
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null
on conflict (id) do nothing;


-- ─────────────────────────────────────────────────────────────
-- 2) 硬化 handle_new_user trigger（幂等 insert）
-- ─────────────────────────────────────────────────────────────
create or replace function public.handle_new_user()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
as $$
begin
  insert into public.profiles (id, name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', '新球友')
  )
  on conflict (id) do nothing;
  return new;
exception when others then
  return new;
end;
$$;


-- ─────────────────────────────────────────────────────────────
-- 3a) 自愈版 ensure_demo_conversation
-- ─────────────────────────────────────────────────────────────
create or replace function public.ensure_demo_conversation()
  returns uuid
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_conv uuid;
begin
  if v_user is null then
    raise exception 'Not authenticated';
  end if;

  insert into profiles (id, name)
  select u.id, coalesce(u.raw_user_meta_data->>'name', '新球友')
  from auth.users u
  where u.id = v_user
  on conflict (id) do nothing;

  select conv_id into v_conv
    from conversation_members
    where user_id = v_user
    limit 1;

  if v_conv is not null then
    return v_conv;
  end if;

  insert into conversations (kind, title)
  values ('group', '球局 · 新手大厅')
  returning id into v_conv;

  insert into conversation_members (conv_id, user_id, unread)
  values (v_conv, v_user, 0);

  insert into messages (conv_id, sender_id, body, kind)
  values (v_conv, null, '欢迎来到球局 · 新手大厅。这里是测试聊天室，随便发条消息试试。', 'system');

  return v_conv;
end;
$$;

grant execute on function public.ensure_demo_conversation() to authenticated, anon;


-- ─────────────────────────────────────────────────────────────
-- 3b) 自愈版 ensure_event_conversation
-- ─────────────────────────────────────────────────────────────
create or replace function public.ensure_event_conversation(p_event_id text)
  returns uuid
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_title text := 'event:' || p_event_id;
  v_conv uuid;
begin
  if v_user is null then
    raise exception 'Not authenticated';
  end if;

  insert into profiles (id, name)
  select u.id, coalesce(u.raw_user_meta_data->>'name', '新球友')
  from auth.users u
  where u.id = v_user
  on conflict (id) do nothing;

  select id into v_conv from conversations where title = v_title limit 1;

  if v_conv is null then
    insert into conversations (kind, title)
    values ('group', v_title)
    returning id into v_conv;
  end if;

  insert into conversation_members (conv_id, user_id, unread)
  values (v_conv, v_user, 0)
  on conflict (conv_id, user_id) do nothing;

  return v_conv;
end;
$$;

grant execute on function public.ensure_event_conversation(text) to authenticated;


-- ─────────────────────────────────────────────────────────────
-- 验证（可选）：运行后应返回 0 行
-- ─────────────────────────────────────────────────────────────
-- select u.id
-- from auth.users u
-- left join public.profiles p on p.id = u.id
-- where p.id is null;
