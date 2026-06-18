-- ============================================================
--  JURAPOTES — Profil enrichi (suite) : anniversaire, formation, situation
--  À exécuter dans Supabase > SQL Editor. Idempotent.
-- ============================================================
alter table public.profiles add column if not exists birthday        date;
alter table public.profiles add column if not exists show_birth_year boolean default false;  -- afficher l'année ?
alter table public.profiles add column if not exists school          text;   -- formation / études
alter table public.profiles add column if not exists relationship    text;   -- situation amoureuse
