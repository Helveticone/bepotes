-- ============================================================
--  JURAPOTES — Modération & blocage
--  À exécuter dans Supabase > SQL Editor (après TOUT-LE-SQL.sql).
--  Sûr à ré-exécuter.
-- ============================================================

-- ---- 1. BLOCAGE d'utilisateurs ----
create table if not exists public.blocks (
  blocker_id uuid references public.profiles(id) on delete cascade not null,
  blocked_id uuid references public.profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

alter table public.blocks enable row level security;

drop policy if exists "voir mes blocages" on public.blocks;
create policy "voir mes blocages" on public.blocks for select
  using ( auth.uid() = blocker_id );

drop policy if exists "bloquer" on public.blocks;
create policy "bloquer" on public.blocks for insert
  with check ( auth.uid() = blocker_id );

drop policy if exists "débloquer" on public.blocks;
create policy "débloquer" on public.blocks for delete
  using ( auth.uid() = blocker_id );


-- ---- 2. SIGNALEMENTS (la table reports existe déjà dans schema.sql) ----
-- On s'assure que les colonnes utiles existent.
alter table public.reports add column if not exists target_type text;   -- 'post' | 'user'
alter table public.reports add column if not exists details text;

-- (Les policies d'insert/select de reports sont déjà dans schema.sql :
--  un membre peut signaler et voir ses propres signalements.)


-- ---- 3. ADMIN : drapeau sur le profil ----
alter table public.profiles add column if not exists is_admin boolean default false;
alter table public.profiles add column if not exists is_banned boolean default false;

-- Fonction pratique : l'utilisateur courant est-il admin ?
create or replace function public.is_admin()
returns boolean language sql security definer set search_path = public as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

-- Un admin peut voir TOUS les signalements (en plus des siens)
drop policy if exists "admin voit les signalements" on public.reports;
create policy "admin voit les signalements" on public.reports for select
  using ( public.is_admin() );

-- Un admin peut mettre à jour le statut d'un signalement
drop policy if exists "admin met à jour les signalements" on public.reports;
create policy "admin met à jour les signalements" on public.reports for update
  using ( public.is_admin() );

-- Un admin peut supprimer n'importe quelle publication (modération)
drop policy if exists "admin supprime un post" on public.posts;
create policy "admin supprime un post" on public.posts for delete
  using ( auth.uid() = author_id or public.is_admin() );

-- Un admin peut bannir (mettre is_banned) n'importe quel profil
drop policy if exists "admin gère les profils" on public.profiles;
create policy "admin gère les profils" on public.profiles for update
  using ( auth.uid() = id or public.is_admin() );


-- ============================================================
--  POUR TE DÉSIGNER ADMIN (remplace par TON email) :
--
--  update public.profiles set is_admin = true
--  where id = (select id from auth.users where email = 'TON-EMAIL@exemple.ch');
--
--  Lance cette commande une fois, avec ton vrai e-mail, pour
--  accéder au tableau de bord de modération (panneau-hcm-7x2k9.html).
-- ============================================================
