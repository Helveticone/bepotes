-- ============================================================
--  BEPOTES — Stories éphémères (24 h)
--  À exécuter dans Supabase > SQL Editor. Idempotent.
--  ------------------------------------------------------------
--  Une story = une image/vidéo (+ texte) qui expire après 24 h.
--  Seules les stories actives (expires_at > now()) sont visibles (RLS).
--  story_views : qui a vu quoi (pour l'anneau « non vu » + le compteur).
-- ============================================================
create table if not exists public.stories (
  id         uuid primary key default gen_random_uuid(),
  author_id  uuid references public.profiles(id) on delete cascade not null,
  media_url  text not null,
  media_type text default 'image',            -- 'image' | 'video'
  text       text,
  created_at timestamptz default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);
create index if not exists stories_active_idx on public.stories(expires_at);
create index if not exists stories_author_idx on public.stories(author_id, created_at);

alter table public.stories enable row level security;
drop policy if exists "stories actives visibles" on public.stories;
create policy "stories actives visibles" on public.stories for select
  using ( auth.uid() is not null and expires_at > now() );
drop policy if exists "publier une story" on public.stories;
create policy "publier une story" on public.stories for insert
  with check ( auth.uid() = author_id );
drop policy if exists "supprimer sa story" on public.stories;
create policy "supprimer sa story" on public.stories for delete
  using ( auth.uid() = author_id );

create table if not exists public.story_views (
  story_id   uuid references public.stories(id) on delete cascade,
  user_id    uuid references public.profiles(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (story_id, user_id)
);
alter table public.story_views enable row level security;
drop policy if exists "vues visibles" on public.story_views;
create policy "vues visibles" on public.story_views for select using ( auth.uid() is not null );
drop policy if exists "marquer vu" on public.story_views;
create policy "marquer vu" on public.story_views for insert with check ( auth.uid() = user_id );
