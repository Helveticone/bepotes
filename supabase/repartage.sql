-- ============================================================
--  BEPOTES — Repartage de publications
--  À exécuter dans Supabase > SQL Editor (après TOUT-LE-SQL.sql).
--  Sûr à ré-exécuter (idempotent).
--  Une publication peut en "repartager" une autre (shared_post_id).
-- ============================================================
alter table public.posts
  add column if not exists shared_post_id uuid references public.posts(id) on delete set null;

create index if not exists posts_shared_idx on public.posts(shared_post_id);

-- (Aucune nouvelle policy : les publications repartagées suivent les
--  mêmes règles de lecture/écriture que les publications normales.)
