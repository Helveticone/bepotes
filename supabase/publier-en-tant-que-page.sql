-- ============================================================
--  47. PUBLIER EN TANT QUE PAGE
--  posts.page_id = « publié EN TANT QUE cette page ». Le post garde
--  author_id = le gestionnaire (RLS/audit) mais group_id reste NULL,
--  donc il APPARAÎT DANS LE FIL, affiché avec l'identité de la page.
--  Insertion « as page » réservée aux gestionnaires (owner/admin).
-- ============================================================
alter table public.posts add column if not exists page_id uuid references public.groups(id) on delete cascade;
create index if not exists posts_page_idx on public.posts(page_id, created_at desc);

-- Policy d'insertion : son propre author_id ; et si page_id est posé, il faut gérer la page.
drop policy if exists "publier en son nom" on public.posts;
drop policy if exists "posts_insert" on public.posts;
create policy "posts_insert" on public.posts for insert with check (
  auth.uid() = author_id
  and ( page_id is null or public.is_group_manager(page_id) )
);

-- Backfill : les publications faites sur le MUR d'une PAGE deviennent des posts
-- « en tant que page » (page_id) -> elles apparaissent dans le fil + sur le mur.
-- Les groupes (communautés) ne sont pas touchés (restent en group_id, hors fil).
update public.posts p set page_id = p.group_id, group_id = null
  where p.group_id in (select id from public.groups where kind = 'page') and p.page_id is null;

notify pgrst, 'reload schema';
