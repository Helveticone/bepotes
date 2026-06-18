-- ============================================================
--  REELS — vidéos verticales courtes (type FB/Insta)
--  Un reel = une publication posts avec is_reel=true.
--  Exclu du fil normal ; affiché dans le carrousel + lecteur plein écran.
--  (Idempotent ; à relancer dans Supabase SQL Editor.)
-- ============================================================
alter table public.posts add column if not exists is_reel boolean not null default false;
create index if not exists posts_reel_idx on public.posts(created_at desc) where is_reel = true;
notify pgrst, 'reload schema';
