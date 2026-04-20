-- 0009_ensure_demo_conversation.sql — per-user bootstrap for Messages demo
--
-- Every anon user needs at least one chat to play with. Client calls
-- `supabase.rpc('ensure_demo_conversation')` on first Messages tab open.
--
-- Behaviour:
--   1. If the caller is already in a conversation → no-op (returns existing
--      conversation id).
--   2. Otherwise, create a new conversation titled "球局 · 新手大厅",
--      add the caller as a member, and seed one welcome message from a
--      system sender (sender_id is null → client shows as "系统").
--
-- Returns the conversation id either way so the client can navigate.

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

-- Allow authenticated users (including anon) to invoke the function.
grant execute on function public.ensure_demo_conversation() to authenticated, anon;
