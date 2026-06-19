-- ============================================================
--  DASHBOARD ADMIN — modèle de données + agrégats (sections 40-41)
--  Tout est admin-only (is_admin()) et calculé CÔTÉ BASE (faible egress).
--  Idempotent. À coller dans Supabase SQL Editor.
-- ============================================================

-- ----- 40. Présence / activité -----
alter table public.profiles add column if not exists last_seen_at timestamptz;
create index if not exists profiles_last_seen_idx on public.profiles(last_seen_at);

create table if not exists public.user_activity (
  user_id uuid references public.profiles(id) on delete cascade,
  day date not null,
  primary key (user_id, day)
);
create index if not exists user_activity_day_idx on public.user_activity(day);
alter table public.user_activity enable row level security;
drop policy if exists "ua_self" on public.user_activity;
create policy "ua_self" on public.user_activity for select using ( auth.uid() = user_id );

-- Marque l'utilisateur courant comme actif (appelé au chargement de l'app, throttlé côté client)
create or replace function public.touch_last_seen()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  update public.profiles set last_seen_at = now() where id = auth.uid();
  insert into public.user_activity (user_id, day) values (auth.uid(), current_date)
    on conflict (user_id, day) do nothing;
end; $$;
grant execute on function public.touch_last_seen() to authenticated;


-- ----- 41. Fonctions d'agrégation (admin-only) -----

-- Vue d'ensemble (cartes chiffres)
create or replace function public.admin_stats_overview()
returns json language plpgsql security definer set search_path = public as $$
declare j json;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  select json_build_object(
    'users_total',     (select count(*) from profiles),
    'users_today',     (select count(*) from profiles where created_at >= current_date),
    'users_7d',        (select count(*) from profiles where created_at >= now()-interval '7 days'),
    'active_today',    (select count(*) from profiles where last_seen_at >= current_date),
    'active_7d',       (select count(*) from profiles where last_seen_at >= now()-interval '7 days'),
    'active_30d',      (select count(*) from profiles where last_seen_at >= now()-interval '30 days'),
    'posts_total',     (select count(*) from posts where is_reel = false),
    'posts_today',     (select count(*) from posts where is_reel = false and created_at >= current_date),
    'posts_7d',        (select count(*) from posts where is_reel = false and created_at >= now()-interval '7 days'),
    'reels_total',     (select count(*) from posts where is_reel = true),
    'reels_7d',        (select count(*) from posts where is_reel = true and created_at >= now()-interval '7 days'),
    'comments_total',  (select count(*) from comments),
    'comments_7d',     (select count(*) from comments where created_at >= now()-interval '7 days'),
    'likes_total',     (select count(*) from likes),
    'likes_7d',        (select count(*) from likes where created_at >= now()-interval '7 days'),
    'groups_total',    (select count(*) from groups where coalesce(kind,'group')='group'),
    'groups_7d',       (select count(*) from groups where coalesce(kind,'group')='group' and created_at >= now()-interval '7 days'),
    'pages_total',     (select count(*) from groups where kind='page'),
    'pages_7d',        (select count(*) from groups where kind='page' and created_at >= now()-interval '7 days'),
    'listings_active', (select count(*) from listings where status='active'),
    'events_total',    (select count(*) from events),
    'events_upcoming', (select count(*) from events where starts_at >= now()),
    'messages_7d',     (select count(*) from messages where created_at >= now()-interval '7 days')
  ) into j;
  return j;
end; $$;
grant execute on function public.admin_stats_overview() to authenticated;

-- Croissance journalière (N derniers jours)
create or replace function public.admin_growth_daily(days int default 30)
returns table(day date, new_users int, posts int, active_users int)
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query
  with d as (
    select generate_series(current_date - (greatest(days,1)-1), current_date, interval '1 day')::date as day
  )
  select dd.day,
    (select count(*) from profiles p  where p.created_at::date  = dd.day)::int,
    (select count(*) from posts    po where po.created_at::date = dd.day)::int,
    (select count(*) from user_activity ua where ua.day = dd.day)::int
  from d dd order by dd.day;
end; $$;
grant execute on function public.admin_growth_daily(int) to authenticated;

-- Rétention (v1 : basée sur last_seen_at)
create or replace function public.admin_retention()
returns json language plpgsql security definer set search_path = public as $$
declare j json;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  select json_build_object(
    'ratio_active', case when (select count(*) from profiles)=0 then 0
        else round(100.0*(select count(*) from profiles where last_seen_at >= now()-interval '7 days')
             / (select count(*) from profiles),1) end,
    'j1',  (select case when count(*)=0 then null else
              round(100.0*count(*) filter (where last_seen_at > created_at + interval '1 day')/count(*),1) end
            from profiles where created_at <= now()-interval '1 day'),
    'j7',  (select case when count(*)=0 then null else
              round(100.0*count(*) filter (where last_seen_at >= created_at + interval '7 days')/count(*),1) end
            from profiles where created_at <= now()-interval '7 days'),
    'j30', (select case when count(*)=0 then null else
              round(100.0*count(*) filter (where last_seen_at >= created_at + interval '30 days')/count(*),1) end
            from profiles where created_at <= now()-interval '30 days')
  ) into j;
  return j;
end; $$;
grant execute on function public.admin_retention() to authenticated;

-- Top communes (utilisateurs + posts)
create or replace function public.admin_top_towns()
returns table(town text, users int, posts int)
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query
  with u as (select town, count(*)::int c from profiles where town is not null and town <> '' group by town),
       p as (select town, count(*)::int c from posts    where town is not null and town <> '' group by town)
  select coalesce(u.town,p.town) as town, coalesce(u.c,0) as users, coalesce(p.c,0) as posts
  from u full outer join p on u.town = p.town
  order by users desc, posts desc
  limit 15;
end; $$;
grant execute on function public.admin_top_towns() to authenticated;

-- Business / pages établissement
create or replace function public.admin_business()
returns json language plpgsql security definer set search_path = public as $$
declare j json;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  select json_build_object(
    'pages_total',   (select count(*) from groups where kind='page'),
    'pages_7d',      (select count(*) from groups where kind='page' and created_at >= now()-interval '7 days'),
    'pages_active',  (select count(*) from groups g where g.kind='page'
                        and exists (select 1 from posts po where po.group_id = g.id)),
    'reviews_total', (select count(*) from page_reviews),
    'reviews_avg',   (select coalesce(round(avg(rating)::numeric,2),0) from page_reviews)
  ) into j;
  return j;
end; $$;
grant execute on function public.admin_business() to authenticated;

-- Modération
create or replace function public.admin_moderation()
returns json language plpgsql security definer set search_path = public as $$
declare j json;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  select json_build_object(
    'reports_open',  (select count(*) from reports where status='open'),
    'reports_done',  (select count(*) from reports where status <> 'open'),
    'reports_oldest_days', (select coalesce(floor(extract(epoch from now()-min(created_at))/86400),0)
                            from reports where status='open'),
    'queue_open',    (select count(*) from mod_queue where status='open')
  ) into j;
  return j;
end; $$;
grant execute on function public.admin_moderation() to authenticated;
