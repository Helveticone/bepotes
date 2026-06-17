-- ============================================================
--  JURAPOTES — Événements : date de fin + photos
--  À exécuter dans Supabase > SQL Editor (après TOUT-LE-SQL.sql).
--  Sûr à ré-exécuter (idempotent).
--  (cover_url existe déjà dans la table events ; starts_at aussi.)
-- ============================================================
alter table public.events add column if not exists ends_at timestamptz;
alter table public.events add column if not exists images text[] default '{}';
