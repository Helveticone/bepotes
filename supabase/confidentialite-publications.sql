-- ============================================================
--  51. CONFIDENTIALITÉ DES PUBLICATIONS (Tout le Jura / Amis seulement)
--  posts.visibility = 'all' (tous les membres, défaut) | 'friends' (amis only).
--  La confidentialité est appliquée par RLS (lecture) : un post 'friends'
--  n'est visible que par l'auteur, ses amis, et les admins.
--  Les posts de groupe/page restent 'all' (gérés par leur propre logique).
-- ============================================================
alter table public.posts add column if not exists visibility text default 'all';

drop policy if exists "publications visibles par les membres" on public.posts;
drop policy if exists "posts_select" on public.posts;
create policy "posts_select" on public.posts for select using (
  auth.uid() is not null and (
    coalesce(visibility,'all') = 'all'
    or author_id = auth.uid()
    or public.are_friends(author_id)
    or public.is_admin()
  )
);
notify pgrst, 'reload schema';
