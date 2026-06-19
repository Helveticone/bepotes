-- ============================================================
--  48. PARAMÈTRES DE PUBLICATION DES GROUPES
--  - post_policy  : 'all' (tous les membres) | 'admins' (gestionnaires seuls)
--  - post_approval: les publications des membres passent en attente (pending)
--                   jusqu'à validation par un gestionnaire.
--  (La validation des ADHÉSIONS existe déjà via groups.is_private.)
-- ============================================================
alter table public.groups add column if not exists post_policy   text default 'all';
alter table public.groups add column if not exists post_approval boolean default false;
alter table public.posts  add column if not exists pending boolean default false;
create index if not exists posts_group_pending_idx on public.posts(group_id, pending, created_at desc);

-- Insertion : règle « page » (section 47) + contrainte « groupe » (qui publie + validation).
-- Pour un membre non-gestionnaire dans un groupe : autorisé seulement si la page est
-- ouverte à tous (post_policy='all') ET que pending == post_approval du groupe
-- (donc si l'approbation est active, le post DOIT être créé en pending).
drop policy if exists "publier en son nom" on public.posts;
drop policy if exists "posts_insert" on public.posts;
create policy "posts_insert" on public.posts for insert with check (
  auth.uid() = author_id
  and ( page_id is null or public.is_group_manager(page_id) )
  and (
    group_id is null
    or public.is_group_manager(group_id)
    or exists (
      select 1 from public.groups g
      where g.id = group_id
        and coalesce(g.post_policy,'all') = 'all'
        and pending = coalesce(g.post_approval,false)
    )
  )
);

-- Un gestionnaire peut valider (pending->false) / modérer les posts de SON groupe.
drop policy if exists "valider les posts du groupe" on public.posts;
create policy "valider les posts du groupe" on public.posts for update
  using ( group_id is not null and public.is_group_manager(group_id) )
  with check ( group_id is not null and public.is_group_manager(group_id) );

-- Un gestionnaire peut refuser (supprimer) un post de son groupe.
drop policy if exists "supprimer les posts du groupe" on public.posts;
create policy "supprimer les posts du groupe" on public.posts for delete
  using ( group_id is not null and public.is_group_manager(group_id) );

notify pgrst, 'reload schema';
