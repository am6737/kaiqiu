-- 0004_messages.sql — 会话 + 消息 + Realtime 订阅 (idempotent)

-- Clean slate for re-runs
drop table if exists messages cascade;
drop table if exists conversation_members cascade;
drop table if exists conversations cascade;
drop function if exists on_message_created();

create table conversations (
  id uuid primary key default gen_random_uuid(),
  kind text default 'dm',               -- dm / group / team
  title text,                           -- for groups
  updated_at timestamptz default now()
);

create table conversation_members (
  conv_id uuid references conversations on delete cascade,
  user_id uuid references profiles on delete cascade,
  unread int default 0,
  last_read_at timestamptz default now(),
  primary key (conv_id, user_id)
);

alter table conversation_members enable row level security;
create policy "members self read" on conversation_members for select using (user_id = auth.uid());

create table messages (
  id uuid primary key default gen_random_uuid(),
  conv_id uuid references conversations on delete cascade,
  sender_id uuid references profiles,
  body text,
  kind text default 'text',             -- text / image / system
  created_at timestamptz default now()
);

create index messages_conv_idx on messages (conv_id, created_at desc);

alter table messages enable row level security;

create policy "messages member read" on messages for select using (
  exists (
    select 1 from conversation_members m
    where m.conv_id = messages.conv_id and m.user_id = auth.uid()
  )
);

create policy "messages member write" on messages for insert with check (
  sender_id = auth.uid()
  and exists (
    select 1 from conversation_members m
    where m.conv_id = messages.conv_id and m.user_id = auth.uid()
  )
);

-- Bump conversation.updated_at + increment unread on new message
create or replace function on_message_created() returns trigger language plpgsql as $$
begin
  update conversations set updated_at = now() where id = new.conv_id;
  update conversation_members
    set unread = unread + 1
    where conv_id = new.conv_id and user_id != new.sender_id;
  return new;
end;
$$;

drop trigger if exists message_created on messages;
create trigger message_created
  after insert on messages
  for each row execute function on_message_created();

-- Enable Realtime subscriptions for messages
alter publication supabase_realtime add table messages;
