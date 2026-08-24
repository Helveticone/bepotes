-- ============================================================
--  BEPOTES — Commune sur les publications (filtre local)
--  À exécuter dans Supabase > SQL Editor. Idempotent.
--  ------------------------------------------------------------
--  On dénormalise la commune de l'auteur sur le post (posts.town)
--  pour filtrer le fil par commune simplement et rapidement.
--  Les nouveaux posts la reçoivent à la publication (côté app) ;
--  on remplit ici les posts existants.
-- ============================================================
alter table public.posts add column if not exists town text;
create index if not exists posts_town_idx on public.posts(town);

update public.posts p
   set town = pr.town
  from public.profiles pr
 where p.author_id = pr.id and p.town is null;
