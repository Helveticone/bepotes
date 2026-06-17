-- ============================================================
--  JURAPOTES — Groupes : administrateurs + règles + couverture
--  À exécuter dans Supabase > SQL Editor (après TOUT-LE-SQL.sql).
--  Sûr à ré-exécuter (idempotent).
--  ------------------------------------------------------------
--  Objectif (façon Facebook) :
--   - un groupe a des RÈGLES (texte) affichées à tous ;
--   - le créateur (owner) ET les administrateurs (role='admin')
--     peuvent éditer le groupe (couverture, règles, infos) et
--     gérer les membres (approuver, promouvoir/rétrograder, retirer) ;
--   - l'owner est protégé : il ne peut être ni rétrogradé ni
--     dépossédé de la propriété par un admin.
-- ============================================================

-- ---- 1. Règles du groupe ----
alter table public.groups add column if not exists rules text;

-- ---- 2. Fonction : l'utilisateur courant gère-t-il ce groupe ? ----
--  (owner OU admin). security definer => contourne la RLS à l'intérieur,
--  ce qui évite toute récursion sur group_members.
create or replace function public.is_group_manager(gid uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.groups g
    where g.id = gid and g.owner_id = auth.uid()
  ) or exists (
    select 1 from public.group_members m
    where m.group_id = gid and m.user_id = auth.uid() and m.role = 'admin'
  );
$$;

-- ---- 3. Édition du groupe : owner OU admin ----
--  (remplace l'ancienne policy "modifier son groupe" réservée à l'owner)
drop policy if exists "modifier son groupe" on public.groups;
drop policy if exists "gerer le groupe" on public.groups;
create policy "gerer le groupe" on public.groups for update
  using ( public.is_group_manager(id) );

-- ---- 4. Trigger anti-escalade : seul l'owner actuel peut changer owner_id ----
--  Empêche un admin de s'attribuer la propriété via un UPDATE du groupe.
create or replace function public.protect_group_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.owner_id is distinct from old.owner_id and old.owner_id <> auth.uid() then
    new.owner_id := old.owner_id;   -- on ignore silencieusement la tentative
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_group_owner on public.groups;
create trigger trg_protect_group_owner
  before update on public.groups
  for each row execute function public.protect_group_owner();

-- ---- 5. Gestion des membres par les managers (owner/admin) ----
--  UPDATE : approuver (pending->member), promouvoir (member->admin),
--  rétrograder (admin->member). On ne touche JAMAIS la ligne de l'owner,
--  et with check interdit de fabriquer un 2e 'owner'.
drop policy if exists "owner gère les membres" on public.group_members;
drop policy if exists "managers gerent les membres" on public.group_members;
create policy "managers gerent les membres" on public.group_members for update
  using ( public.is_group_manager(group_id) and role <> 'owner' )
  with check ( role in ('member','admin','pending') );

-- DELETE : on peut se retirer soi-même, ou un manager retire un membre
--  (jamais l'owner).
drop policy if exists "quitter un groupe" on public.group_members;
drop policy if exists "owner retire un membre" on public.group_members;
drop policy if exists "retirer un membre" on public.group_members;
create policy "retirer un membre" on public.group_members for delete
  using (
    auth.uid() = user_id
    or ( public.is_group_manager(group_id) and role <> 'owner' )
  );

-- (Les policies d'INSERT — rejoindre / demander — et de SELECT restent
--  inchangées : voir schema.sql / TOUT-LE-SQL.sql.)
