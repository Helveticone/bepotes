-- ============================================================
--  BEPOTES — PURGE DU CONTENU DE DÉMO (rebranding Jurapotes → BePotes)
-- ------------------------------------------------------------
--  ⚠️ DESTRUCTIF ET IRRÉVERSIBLE. À lancer UNE SEULE FOIS, dans
--  Supabase → SQL Editor, pour repartir sur une base vierge :
--  faux comptes, groupes, pages, publications, événements, annonces,
--  messages, notifications, stories, reels… tout part.
--
--  CE QUI EST CONSERVÉ :
--    • les comptes marqués `profiles.is_admin = true` (toi) ;
--    • le schéma, les policies RLS, les fonctions et les triggers ;
--    • la régie publicitaire (`ads`) — décommente sa ligne si tu veux
--      aussi repartir de zéro côté pubs ;
--    • les mots interdits (`banned_words`).
--
--  AVANT DE LANCER :
--    1) Supabase → Database → Backups : prends une sauvegarde.
--    2) Vérifie que TON compte a bien `is_admin = true`
--       (sinon : voir supabase/devenir-admin.sql) :
--          select id, name, is_admin from public.profiles where is_admin;
--    3) Les fichiers déjà déposés dans Storage (avatars/covers/posts/…)
--       ne sont PAS supprimés par ce script : vide les buckets à la main
--       depuis Supabase → Storage si tu veux tout nettoyer.
--
--  Le script tourne dans une transaction. Il se termine par un COMMIT :
--  pour faire un essai à blanc, remplace le COMMIT final par ROLLBACK.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 0) Les comptes à GARDER = les admins
-- ------------------------------------------------------------
create temporary table _keep on commit drop as
  select id from public.profiles where coalesce(is_admin, false);

do $$
begin
  if (select count(*) from _keep) = 0 then
    raise exception
      'Aucun compte admin trouvé : la purge supprimerait TOUS les comptes. '
      'Lance d''abord supabase/devenir-admin.sql, puis relance ce script.';
  end if;
end $$;

-- ------------------------------------------------------------
-- 1) Contenus (ordre : enfants → parents ; les FK sont en cascade,
--    mais on reste explicite pour que le script soit lisible)
-- ------------------------------------------------------------
-- Les tables absentes (section SQL jamais lancée) sont simplement ignorées,
-- pour que le script ne casse pas en cours de route.
do $$
declare
  t text;
  tables text[] := array[
    'story_views','stories',
    'photo_tags','comment_likes','comments','likes','poll_votes',
    'posts',                 -- inclut reels, repartages, sondages
    'album_photos','albums',
    'event_comments','event_attendees',
    'events',                -- inclut le seed « seed-events.sql »
    'page_reviews','group_members',
    'groups',                -- groupes ET pages (kind = group|page)
    'listings',              -- marketplace
    'message_reactions','messages','conversation_members','conversations',
    'notifications','push_subscriptions',
    'follows','friendships','blocks',
    'reports','mod_queue',
    'user_activity','client_errors'
    -- ,'ads'                -- décommente pour repartir de zéro côté régie pub
  ];
begin
  foreach t in array tables loop
    if to_regclass('public.' || t) is null then
      raise notice 'table absente, ignorée : %', t;
    else
      execute format('delete from public.%I', t);
      raise notice 'purgé : %', t;
    end if;
  end loop;
end $$;

-- Gamification : `user_stats` / `leaderboard` sont des FONCTIONS qui recalculent
-- les scores à la volée — rien à purger, elles retomberont à zéro d'elles-mêmes.

-- ------------------------------------------------------------
-- 2) Comptes de test — profils puis utilisateurs Auth
-- ------------------------------------------------------------
delete from public.profiles
 where id not in (select id from _keep);

delete from auth.users
 where id not in (select id from _keep);

-- ------------------------------------------------------------
-- 3) Contrôle final — doit ne lister que tes comptes admin
-- ------------------------------------------------------------
select 'comptes restants' as quoi, count(*) from public.profiles
union all select 'publications',  count(*) from public.posts
union all select 'groupes/pages', count(*) from public.groups
union all select 'événements',    count(*) from public.events
union all select 'annonces',      count(*) from public.listings
union all select 'conversations', count(*) from public.conversations;

commit;
