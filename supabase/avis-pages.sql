-- ============================================================
--  JURAPOTES — Avis & notes (étoiles) sur les Pages
--  À exécuter dans Supabase > SQL Editor (après TOUT-LE-SQL.sql).
--  Sûr à ré-exécuter (idempotent).
--  Une Page (groups.kind='page') peut recevoir des avis notés 1–5.
--  Un membre = un avis par page (modifiable).
-- ============================================================
create table if not exists public.page_reviews (
  id         uuid primary key default gen_random_uuid(),
  page_id    uuid references public.groups(id) on delete cascade not null,
  author_id  uuid references public.profiles(id) on delete cascade not null,
  rating     int not null check (rating between 1 and 5),
  text       text,
  created_at timestamptz default now(),
  unique (page_id, author_id)
);
create index if not exists page_reviews_page_idx on public.page_reviews(page_id);

alter table public.page_reviews enable row level security;

drop policy if exists "avis visibles" on public.page_reviews;
create policy "avis visibles" on public.page_reviews for select
  using ( auth.uid() is not null );

drop policy if exists "laisser un avis" on public.page_reviews;
create policy "laisser un avis" on public.page_reviews for insert
  with check ( auth.uid() = author_id );

drop policy if exists "modifier son avis" on public.page_reviews;
create policy "modifier son avis" on public.page_reviews for update
  using ( auth.uid() = author_id );

drop policy if exists "supprimer son avis" on public.page_reviews;
create policy "supprimer son avis" on public.page_reviews for delete
  using ( auth.uid() = author_id );
