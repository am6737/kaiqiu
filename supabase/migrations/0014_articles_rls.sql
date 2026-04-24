-- Add INSERT/UPDATE/DELETE RLS policies for articles table
-- (SELECT policy already exists in 0001_schema.sql)

create policy "articles self insert" on public.articles for insert
  with check (auth.uid() = author_id);

create policy "articles self update" on public.articles for update
  using (auth.uid() = author_id);

create policy "articles self delete" on public.articles for delete
  using (auth.uid() = author_id);
