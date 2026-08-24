-- ============================================================
--  BEPOTES — Marketplace / petites annonces
--  À exécuter dans Supabase > SQL Editor (après TOUT-LE-SQL.sql).
--  Sûr à ré-exécuter (idempotent).
--  Acheter · vendre · donner entre habitants du Jura.
-- ============================================================
create table if not exists public.listings (
  id          uuid primary key default gen_random_uuid(),
  seller_id   uuid references public.profiles(id) on delete cascade not null,
  title       text not null,
  description text,
  price       numeric(10,2),                 -- null = prix à discuter ; 0 = gratuit
  category    text default 'Divers',
  town        text,
  images      text[] default '{}',
  status      text default 'active',          -- 'active' | 'sold'
  created_at  timestamptz default now()
);
create index if not exists listings_created_idx on public.listings(created_at desc);
create index if not exists listings_seller_idx  on public.listings(seller_id);

alter table public.listings enable row level security;

drop policy if exists "listings_select" on public.listings;
create policy "listings_select" on public.listings for select
  using ( auth.uid() is not null );

drop policy if exists "creer une annonce" on public.listings;
create policy "creer une annonce" on public.listings for insert
  with check ( auth.uid() = seller_id );

drop policy if exists "modifier son annonce" on public.listings;
create policy "modifier son annonce" on public.listings for update
  using ( auth.uid() = seller_id );

drop policy if exists "supprimer son annonce" on public.listings;
create policy "supprimer son annonce" on public.listings for delete
  using ( auth.uid() = seller_id );
