-- ============================================================
--  JURAPOTES — Likes sur les commentaires
--  À exécuter dans Supabase > SQL Editor (après TOUT-LE-SQL.sql).
--  Sûr à ré-exécuter (idempotent).
--  Permet le tri « le plus aimé » sur les commentaires (façon FB).
-- ============================================================
create table if not exists public.comment_likes (
  comment_id uuid references public.comments(id) on delete cascade,
  user_id    uuid references public.profiles(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (comment_id, user_id)
);

alter table public.comment_likes enable row level security;

drop policy if exists "comment_likes_select" on public.comment_likes;
create policy "comment_likes_select" on public.comment_likes for select
  using ( auth.uid() is not null );

drop policy if exists "aimer un commentaire" on public.comment_likes;
create policy "aimer un commentaire" on public.comment_likes for insert
  with check ( auth.uid() = user_id );

drop policy if exists "retirer son like de commentaire" on public.comment_likes;
create policy "retirer son like de commentaire" on public.comment_likes for delete
  using ( auth.uid() = user_id );
