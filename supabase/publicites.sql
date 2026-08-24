-- ============================================================
--  BEPOTES — Régie publicitaire (pubs dans le fil)
--  À exécuter dans Supabase > SQL Editor (après TOUT-LE-SQL.sql).
--  Sûr à ré-exécuter (idempotent).
--  ------------------------------------------------------------
--  - Pubs gérées par les admins (RLS : tout réservé aux admins).
--  - Affichage : fonction active_ads(device) (SECURITY DEFINER) qui
--    ne renvoie que les pubs actives, dans leurs dates, sous le
--    plafond mensuel d'affichages, pour l'écran demandé.
--  - Comptage : ad_impression(id) incrémente un compteur mensuel
--    (réinitialisé au changement de mois).
-- ============================================================
create table if not exists public.ads (
  id              uuid primary key default gen_random_uuid(),
  title           text,
  body            text,                 -- texte affiché au-dessus de l'image (façon FB)
  advertiser      text,                 -- nom de l'annonceur
  contact         text,                 -- e-mail / téléphone (privé, admin only)
  image_pc        text,                 -- URL image format PC
  image_mobile    text,                 -- URL image format mobile
  link_url        text,                 -- lien cible (interne « groupe.html?id=… » ou externe « https://… »)
  active          boolean default true,
  sort_order      int default 0,        -- ordre (drag & drop)
  impressions_cap int default 3000,     -- plafond mensuel d'affichages
  impressions     int default 0,        -- affichages du mois courant
  month_key       text,                 -- 'YYYY-MM' du compteur courant
  plan            text,                 -- 'mois' | 'annee' (info)
  starts_on       date,
  ends_on         date,
  created_at      timestamptz default now()
);
-- Colonne ajoutée après coup (si la table existait déjà) :
alter table public.ads add column if not exists body text;
create index if not exists ads_order_idx on public.ads(sort_order, created_at);

alter table public.ads enable row level security;
-- Tout (lecture détaillée + écriture) réservé aux admins.
drop policy if exists "ads admin" on public.ads;
create policy "ads admin" on public.ads for all
  using ( public.is_admin() ) with check ( public.is_admin() );

-- Affichage public (membres) via fonction : ne renvoie que l'essentiel.
-- (drop d'abord : le type de retour change avec l'ajout de "body")
drop function if exists public.active_ads(text);
create or replace function public.active_ads(device text)
returns table(id uuid, image text, link text, title text, body text)
language sql security definer set search_path = public as $$
  select a.id,
         case when device='mobile' then coalesce(a.image_mobile, a.image_pc)
              else coalesce(a.image_pc, a.image_mobile) end as image,
         a.link_url as link, a.title, a.body
  from public.ads a
  where a.active = true
    and (a.starts_on is null or a.starts_on <= current_date)
    and (a.ends_on   is null or a.ends_on   >= current_date)
    and (case when a.month_key = to_char(now(),'YYYY-MM') then a.impressions else 0 end) < a.impressions_cap
    and (case when device='mobile' then coalesce(a.image_mobile,a.image_pc)
              else coalesce(a.image_pc,a.image_mobile) end) is not null
  order by a.sort_order, a.created_at;
$$;
grant execute on function public.active_ads(text) to authenticated, anon;

-- Compteur de clics du mois courant (réinitialisé en même temps que les affichages).
alter table public.ads add column if not exists clicks int default 0;

-- Comptage d'un affichage (réinitialisation mensuelle automatique).
-- Au changement de mois, on remet À ZÉRO affichages ET clics.
create or replace function public.ad_impression(ad_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare mk text := to_char(now(),'YYYY-MM');
begin
  update public.ads
     set impressions = case when month_key = mk then impressions + 1 else 1 end,
         clicks      = case when month_key = mk then clicks else 0 end,
         month_key   = mk
   where id = ad_id;
end; $$;
grant execute on function public.ad_impression(uuid) to authenticated, anon;

-- Comptage d'un clic (même logique de réinitialisation mensuelle).
create or replace function public.ad_click(ad_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare mk text := to_char(now(),'YYYY-MM');
begin
  update public.ads
     set clicks      = case when month_key = mk then clicks + 1 else 1 end,
         impressions = case when month_key = mk then impressions else 0 end,
         month_key   = mk
   where id = ad_id;
end; $$;
grant execute on function public.ad_click(uuid) to authenticated, anon;
