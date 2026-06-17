-- ============================================================
--  JURAPOTES — Sondages dans les publications
--  À exécuter dans Supabase > SQL Editor. Idempotent.
--  ------------------------------------------------------------
--  - Les options du sondage sont stockées sur le post (poll_options).
--    Le texte du post sert de question.
--  - Un membre = un vote (table poll_votes), modifiable / retirable.
-- ============================================================
alter table public.posts add column if not exists poll_options text[];

create table if not exists public.poll_votes (
  post_id    uuid references public.posts(id) on delete cascade,
  user_id    uuid references public.profiles(id) on delete cascade,
  choice     int not null,                 -- index de l'option choisie
  created_at timestamptz default now(),
  primary key (post_id, user_id)
);
alter table public.poll_votes enable row level security;

drop policy if exists "poll_votes_select" on public.poll_votes;
create policy "poll_votes_select" on public.poll_votes for select using ( auth.uid() is not null );
drop policy if exists "voter a un sondage" on public.poll_votes;
create policy "voter a un sondage" on public.poll_votes for insert with check ( auth.uid() = user_id );
drop policy if exists "changer son vote" on public.poll_votes;
create policy "changer son vote" on public.poll_votes for update using ( auth.uid() = user_id );
drop policy if exists "retirer son vote" on public.poll_votes;
create policy "retirer son vote" on public.poll_votes for delete using ( auth.uid() = user_id );
