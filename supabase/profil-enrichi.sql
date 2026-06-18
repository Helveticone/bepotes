-- ============================================================
--  JURAPOTES — Profil enrichi (« À propos »)
--  À exécuter dans Supabase > SQL Editor. Idempotent.
--  ------------------------------------------------------------
--  Ajoute quelques champs « À propos » au profil :
--   - job     : métier / activité
--   - origin  : commune d'origine
--   - website : lien (site, page, réseau)
--  (Visibles via la policy de lecture des profils déjà en place.)
-- ============================================================
alter table public.profiles add column if not exists job     text;
alter table public.profiles add column if not exists origin  text;
alter table public.profiles add column if not exists website text;
