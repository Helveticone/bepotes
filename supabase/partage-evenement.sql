-- ============================================================
--  52. PARTAGE D'ÉVÉNEMENT DANS LE FIL (carte cliquable)
--  posts.event_id = la publication partage cet événement. L'image du post
--  (couverture de l'événement) devient une carte cliquable vers l'événement.
-- ============================================================
alter table public.posts add column if not exists event_id uuid references public.events(id) on delete set null;
create index if not exists posts_event_idx on public.posts(event_id);
notify pgrst, 'reload schema';
