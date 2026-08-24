-- ============================================================
--  BEPOTES — Pages d'établissement / club
--  À exécuter dans Supabase > SQL Editor (après TOUT-LE-SQL.sql).
--  ------------------------------------------------------------
--  Une "Page" réutilise la table groups mais avec kind='page'
--  et une catégorie. Les membres (group_members) jouent le rôle
--  d'abonnés à la page. Le créateur (owner) publie au nom de la page.
-- ============================================================

alter table public.groups
  add column if not exists kind text default 'group';   -- 'group' | 'page'
alter table public.groups
  add column if not exists category text;               -- ex: Restaurant, Club sportif, Association…
alter table public.groups
  add column if not exists address text;                -- adresse / infos pratiques
alter table public.groups
  add column if not exists phone text;
alter table public.groups
  add column if not exists website text;

-- Rien d'autre à changer : les policies de groups/group_members
-- couvrent déjà la création, l'abonnement (insert membre) et la
-- publication (posts.group_id). Une page = un groupe ouvert dont
-- kind='page'.
