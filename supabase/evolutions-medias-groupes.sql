-- ============================================================
--  JURAPOTES — Évolutions : photos multiples, groupes ouverts/
--  sur validation, demandes d'adhésion.
--  À exécuter dans Supabase > SQL Editor.
-- ============================================================

-- ---- 1. Photos multiples sur les publications ----
-- On ajoute une colonne "images" (liste d'URLs) en plus de l'ancienne
-- "image_url" (gardée pour compatibilité). Jusqu'à 6 côté appli.
alter table public.posts
  add column if not exists images text[] default '{}';

-- ---- 2. Type de groupe : ouvert ou sur validation ----
alter table public.groups
  add column if not exists is_private boolean default false;
-- is_private = false -> on rejoint directement
-- is_private = true  -> il faut demander l'adhésion (validée par l'owner)

-- Le rôle dans group_members sert déjà : 'owner' | 'admin' | 'member'.
-- On ajoute un rôle 'pending' pour les demandes en attente.
-- (rien à modifier dans le schéma, "role" est un text libre)

-- ---- 3. Politique : voir les membres en attente / gérer ----
-- L'owner du groupe peut mettre à jour / supprimer les lignes de membres
-- (pour accepter une demande = passer 'pending' -> 'member', ou retirer).
drop policy if exists "owner gère les membres" on public.group_members;
create policy "owner gère les membres"
  on public.group_members for update
  using (
    exists (select 1 from public.groups g
            where g.id = group_id and g.owner_id = auth.uid())
  );

drop policy if exists "owner retire un membre" on public.group_members;
create policy "owner retire un membre"
  on public.group_members for delete
  using (
    auth.uid() = user_id
    or exists (select 1 from public.groups g
               where g.id = group_id and g.owner_id = auth.uid())
  );

-- ---- 4. Couverture de groupe ----
-- La colonne cover_url existe déjà dans la table groups (schema.sql).
-- L'owner peut déjà faire un UPDATE sur son groupe (policy "modifier son groupe").
-- Rien à ajouter ici.

-- ============================================================
--  Rappel Storage : les buckets "posts" et "covers" servent
--  aussi pour les galeries et couvertures de groupe.
-- ============================================================
