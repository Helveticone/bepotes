-- ============================================================
--  BEPOTES — Événements enrichis (Intéressé + discussion)
--  À exécuter dans Supabase > SQL Editor (après TOUT-LE-SQL.sql).
--  Sûr à ré-exécuter (idempotent).
-- ============================================================

-- 1) Statut de participation : 'going' (je participe) | 'interested' (intéressé)
alter table public.event_attendees
  add column if not exists status text default 'going';

-- 2) Discussion d'un événement (commentaires)
create table if not exists public.event_comments (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid references public.events(id) on delete cascade not null,
  author_id  uuid references public.profiles(id) on delete cascade not null,
  text       text not null,
  created_at timestamptz default now()
);
create index if not exists event_comments_event_idx on public.event_comments(event_id, created_at);

alter table public.event_comments enable row level security;
drop policy if exists "discussion visible" on public.event_comments;
create policy "discussion visible" on public.event_comments for select using ( auth.uid() is not null );
drop policy if exists "commenter un evenement" on public.event_comments;
create policy "commenter un evenement" on public.event_comments for insert with check ( auth.uid() = author_id );
drop policy if exists "modifier son commentaire evenement" on public.event_comments;
create policy "modifier son commentaire evenement" on public.event_comments for update using ( auth.uid() = author_id );
drop policy if exists "supprimer son commentaire evenement" on public.event_comments;
create policy "supprimer son commentaire evenement" on public.event_comments for delete using ( auth.uid() = author_id );
