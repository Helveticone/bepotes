-- ============================================================
--  JURAPOTES — Suggestions d'amis (amis communs prioritaires)
--  À exécuter dans Supabase > SQL Editor (après TOUT-LE-SQL.sql).
--  Sûr à ré-exécuter (idempotent).
--  ------------------------------------------------------------
--  Renvoie des profils à suggérer, classés par nombre d'amis
--  communs décroissant. SECURITY DEFINER car le calcul a besoin
--  de lire le graphe d'amitié au-delà de mes propres lignes.
-- ============================================================
create or replace function public.friend_suggestions(lim int default 10)
returns table(user_id uuid, mutual int)
language sql
security definer
set search_path = public
as $$
  with me as (select auth.uid() as id),
  myfriends as (
    select case when requester_id = (select id from me) then addressee_id else requester_id end as fid
    from public.friendships
    where status = 'accepted'
      and (select id from me) in (requester_id, addressee_id)
  ),
  pending as (
    select case when requester_id = (select id from me) then addressee_id else requester_id end as pid
    from public.friendships
    where status = 'pending'
      and (select id from me) in (requester_id, addressee_id)
  ),
  fof as (
    select case when f.requester_id = mf.fid then f.addressee_id else f.requester_id end as cand
    from public.friendships f
    join myfriends mf on mf.fid in (f.requester_id, f.addressee_id)
    where f.status = 'accepted'
  )
  select cand as user_id, count(*)::int as mutual
  from fof
  where cand <> (select id from me)
    and cand not in (select fid from myfriends)
    and cand not in (select pid from pending)
    and cand not in (select blocked_id from public.blocks where blocker_id = (select id from me))
  group by cand
  order by mutual desc
  limit lim;
$$;

grant execute on function public.friend_suggestions(int) to authenticated, anon;
