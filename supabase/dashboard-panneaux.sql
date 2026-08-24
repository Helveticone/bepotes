-- ============================================================
--  SECTION 54 — Dashboard : acquisition / business / engagement / heures
--  Lecture seule, SAUF la colonne profiles.signup_source (posée à l'INSERT).
--  Idempotent. RPC admin-only (is_admin()). Fuseau Europe/Brussels.
-- ============================================================

-- (a) Source d'inscription (même patron que gender/birthday, section 53)
alter table public.profiles add column if not exists signup_source text;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
declare m jsonb := coalesce(new.raw_user_meta_data,'{}'::jsonb);
begin
  insert into public.profiles (id, name, town, gender, birthday, avatar_url, signup_source)
  values (new.id,
    coalesce(nullif(m->>'name',''), nullif(m->>'full_name',''), 'Nouveau membre'),
    nullif(m->>'town',''), nullif(m->>'gender',''), nullif(m->>'birthday','')::date,
    coalesce(nullif(m->>'avatar_url',''), nullif(m->>'picture','')),
    nullif(m->>'signup_source',''))
  on conflict (id) do nothing;
  return new;
end$$;

-- (b) Acquisition par source (valeurs déjà normalisées côté client)
create or replace function public.admin_acquisition(days int default 30)
returns table(source text, signups bigint)
language plpgsql security definer set search_path=public as $$
begin
  if not public.is_admin() then raise exception 'non autorisé'; end if;
  return query
    select coalesce(nullif(trim(p.signup_source),''),'(inconnu)'), count(*)
    from public.profiles p
    where p.created_at >= now() - make_interval(days => days)
    group by 1 order by 2 desc;
end$$;

-- (c) Business établissements — active = page (kind='page') avec >=1 post / 30j
create or replace function public.admin_pages_status()
returns json language plpgsql security definer set search_path=public as $$
declare r json;
begin
  if not public.is_admin() then raise exception 'non autorisé'; end if;
  select json_build_object(
    'pages_total',  (select count(*) from public.groups where kind='page'),
    'pages_7d',     (select count(*) from public.groups where kind='page' and created_at>=now()-interval '7 days'),
    'pages_30d',    (select count(*) from public.groups where kind='page' and created_at>=now()-interval '30 days'),
    'active_30d',   (select count(distinct g.id) from public.groups g
                       join public.posts po on po.group_id=g.id
                       where g.kind='page' and po.created_at>=now()-interval '30 days'),
    'reviews_total',(select count(*) from public.page_reviews),
    'reviews_30d',  (select count(*) from public.page_reviews where created_at>=now()-interval '30 days')
  ) into r; return r;
end$$;

-- (d) Funnel engagement (tiers EXCLUSIFs -> aucun double-comptage)
create or replace function public.admin_engagement(days int default 30)
returns json language plpgsql security definer set search_path=public as $$
declare r json; t timestamptz := now() - make_interval(days => days);
begin
  if not public.is_admin() then raise exception 'non autorisé'; end if;
  with posted    as (select distinct author_id uid from public.posts    where created_at>=t),
       commented as (select distinct author_id uid from public.comments where created_at>=t),
       reacted   as (select distinct user_id  uid from public.likes    where created_at>=t),
       engaged   as (select uid from commented union select uid from reacted),
       active    as (select id uid from public.profiles where last_seen_at>=t),
       base      as (select uid from active union select uid from posted union select uid from engaged)
  select json_build_object(
    'active',   (select count(*) from base),
    'creators', (select count(*) from posted),
    'engagers', (select count(*) from engaged e where e.uid not in (select uid from posted)),
    'lurkers',  (select count(*) from base b where b.uid not in (select uid from posted)
                                              and b.uid not in (select uid from engaged))
  ) into r; return r;
end$$;

-- (e) Audience par heure — UNION de tables réellement horodatées (user_activity.day
--     est une DATE pure, inexploitable pour l'heure). 7j glissants, Europe/Brussels.
create or replace function public.admin_activity_by_hour()
returns table(heure int, evenements bigint)
language plpgsql security definer set search_path=public as $$
begin
  if not public.is_admin() then raise exception 'non autorisé'; end if;
  return query
    with ev as (
      select created_at from public.posts    where created_at >= now()-interval '7 days'
      union all select created_at from public.comments where created_at >= now()-interval '7 days'
      union all select created_at from public.likes    where created_at >= now()-interval '7 days'
      union all select created_at from public.messages where created_at >= now()-interval '7 days'
    )
    select extract(hour from (created_at at time zone 'Europe/Brussels'))::int, count(*)
    from ev group by 1 order by 1;
end$$;

grant execute on function public.admin_acquisition(int) to authenticated;
grant execute on function public.admin_pages_status() to authenticated;
grant execute on function public.admin_engagement(int) to authenticated;
grant execute on function public.admin_activity_by_hour() to authenticated;

notify pgrst, 'reload schema';
