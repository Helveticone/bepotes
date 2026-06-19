-- ============================================================
--  45. GAMIFICATION & RÉPUTATION (scores calculés, sans triggers)
--  Les scores/badges sont CALCULÉS à la demande depuis les données
--  existantes (pas de colonne compteur à maintenir, pas de trigger).
--    - user_stats(uid)        : compteurs d'un membre (profil)
--    - leaderboard(period,lim): classement (mois courant ou tout temps)
-- ============================================================

create or replace function public.user_stats(uid uuid)
returns json language plpgsql security definer set search_path = public as $$
declare j json;
begin
  if auth.uid() is null then raise exception 'non authentifié'; end if;
  select json_build_object(
    'posts',          (select count(*) from posts    where author_id = uid and not coalesce(is_reel,false)),
    'reels',          (select count(*) from posts    where author_id = uid and coalesce(is_reel,false)),
    'comments',       (select count(*) from comments where author_id = uid),
    'likes_received', (select count(*) from likes l join posts p on p.id = l.post_id where p.author_id = uid),
    'likes_given',    (select count(*) from likes    where user_id = uid),
    'friends',        (select count(*) from friendships where status='accepted' and (requester_id = uid or addressee_id = uid)),
    'events',         (select count(*) from events   where creator_id = uid),
    'photos',         (select count(*) from album_photos where owner_id = uid),
    'member_since',   (select created_at from profiles where id = uid)
  ) into j;
  return j;
end; $$;
grant execute on function public.user_stats(uuid) to authenticated;

create or replace function public.leaderboard(period text default 'all', lim int default 20)
returns table(user_id uuid, name text, avatar text, town text, score int, posts int, comments int, likes_recv int)
language plpgsql security definer set search_path = public as $$
declare since timestamptz;
begin
  if auth.uid() is null then raise exception 'non authentifié'; end if;
  since := case when period = 'month' then date_trunc('month', now()) else '1970-01-01'::timestamptz end;
  return query
  with po as (
    select author_id as uid,
           count(*) filter (where not coalesce(is_reel,false))::int as nposts,
           count(*) filter (where     coalesce(is_reel,false))::int as nreels
    from posts where created_at >= since group by author_id
  ),
  co as (
    select author_id as uid, count(*)::int as ncomments
    from comments where created_at >= since group by author_id
  ),
  lk as (
    select p.author_id as uid, count(*)::int as nlikes
    from likes l join posts p on p.id = l.post_id
    where l.created_at >= since group by p.author_id
  ),
  ranked as (
    select pr.id as uid, pr.name as nm, pr.avatar_url as av, pr.town as tw,
      (coalesce(po.nposts,0)*5 + coalesce(po.nreels,0)*8 + coalesce(co.ncomments,0)*2 + coalesce(lk.nlikes,0))::int as sc,
      coalesce(po.nposts,0)::int as np, coalesce(co.ncomments,0)::int as nc, coalesce(lk.nlikes,0)::int as nl,
      pr.created_at as cr
    from profiles pr
    left join po on po.uid = pr.id
    left join co on co.uid = pr.id
    left join lk on lk.uid = pr.id
    where coalesce(pr.is_banned,false) = false
  )
  select uid, nm, av, tw, sc, np, nc, nl
  from ranked where sc > 0
  order by sc desc, cr asc
  limit greatest(lim,1);
end; $$;
grant execute on function public.leaderboard(text,int) to authenticated;

notify pgrst, 'reload schema';
