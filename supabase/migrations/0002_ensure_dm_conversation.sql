-- 0002_ensure_dm_conversation.sql
-- 新增 1v1 DM 的幂等"找到或创建"RPC + DM 对端查询 view。
-- 与 0001_schema.sql 保持风格一致：security definer, search_path=public, grant to authenticated。

-- 并发 tradeoff：conversations 表上不存在"(DM 双方) 唯一键"这种约束，
-- 所以严格的幂等只在串行调用下成立。两个客户端同时首次为 A↔B 发起 DM
-- 时，理论上各自插入一条，产生重复会话。发生概率极低；读方永远以 RPC
-- 本次返回的 id 为准，不阻塞用户。

-- ───────────────────────────────────────────────────────────────
-- ensure_dm_conversation(p_other_user_id uuid) → uuid
--   当前用户 v_me 与 p_other_user_id 之间若已存在 kind='dm' 且成员恰
--   为 {v_me, other} 的会话，返回该 id；否则新建并插入两位成员。
-- ───────────────────────────────────────────────────────────────

drop function if exists public.ensure_dm_conversation(uuid);

create function public.ensure_dm_conversation(p_other_user_id uuid)
  returns uuid
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_id uuid;
begin
  if v_me is null then
    raise exception 'not_authenticated';
  end if;
  if p_other_user_id is null then
    raise exception 'other_required';
  end if;
  if p_other_user_id = v_me then
    raise exception 'cannot_dm_self';
  end if;
  if not exists (select 1 from profiles where id = p_other_user_id) then
    raise exception 'user_not_found';
  end if;

  -- 查：kind='dm' 且成员恰等于 {v_me, p_other_user_id} 的会话
  select c.id into v_id
  from conversations c
  where c.kind = 'dm'
    and exists (select 1 from conversation_members m
                where m.conv_id = c.id and m.user_id = v_me)
    and exists (select 1 from conversation_members m
                where m.conv_id = c.id and m.user_id = p_other_user_id)
    and (select count(*) from conversation_members m
         where m.conv_id = c.id) = 2
  limit 1;

  if v_id is not null then
    return v_id;
  end if;

  -- 建：conversations 表无 created_by 列，只填 kind
  insert into conversations (kind) values ('dm') returning id into v_id;

  insert into conversation_members (conv_id, user_id, unread)
  values (v_id, v_me, 0), (v_id, p_other_user_id, 0);

  return v_id;
end;
$$;

grant execute on function public.ensure_dm_conversation(uuid) to authenticated;


-- ───────────────────────────────────────────────────────────────
-- v_conversation_peers
--   列出每个 DM 会话的成员 user_id，供客户端按 conv_id + peer_user_id <> me
--   查询对端 uid（用于消息列表与聊天页显示对方名字/头像）。
-- ───────────────────────────────────────────────────────────────

create or replace view public.v_conversation_peers as
select m.conv_id as conv_id,
       m.user_id as peer_user_id
from conversation_members m
join conversations c on c.id = m.conv_id
where c.kind = 'dm'
  -- Safety: caller must be a member of this DM to see either member row.
  -- Prevents any authenticated user from enumerating the full "who DMs
  -- whom" social graph via this view.
  and exists (
    select 1 from conversation_members me
    where me.conv_id = m.conv_id and me.user_id = auth.uid()
  );

grant select on public.v_conversation_peers to authenticated;
