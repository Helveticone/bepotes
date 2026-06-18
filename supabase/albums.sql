-- ============================================================
--  JURAPOTES — Albums photos (profil)
--  À exécuter dans Supabase > SQL Editor. Idempotent.
--  ------------------------------------------------------------
--  Un membre organise ses photos en albums. Visibles par les membres
--  connectés (lecture) ; gestion réservée au propriétaire.
-- ============================================================
create table if not exists public.albums (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid references public.profiles(id) on delete cascade not null,
  title      text not null,
  cover_url  text,
  created_at timestamptz default now()
);
create index if not exists albums_owner_idx on public.albums(owner_id, created_at desc);

create table if not exists public.album_photos (
  id         uuid primary key default gen_random_uuid(),
  album_id   uuid references public.albums(id) on delete cascade not null,
  owner_id   uuid references public.profiles(id) on delete cascade not null,
  url        text not null,
  created_at timestamptz default now()
);
create index if not exists album_photos_album_idx on public.album_photos(album_id, created_at);

alter table public.albums enable row level security;
alter table public.album_photos enable row level security;

drop policy if exists "albums_select" on public.albums;
create policy "albums_select" on public.albums for select using ( auth.uid() is not null );
drop policy if exists "albums_insert" on public.albums;
create policy "albums_insert" on public.albums for insert with check ( auth.uid() = owner_id );
drop policy if exists "albums_update" on public.albums;
create policy "albums_update" on public.albums for update using ( auth.uid() = owner_id );
drop policy if exists "albums_delete" on public.albums;
create policy "albums_delete" on public.albums for delete using ( auth.uid() = owner_id );

drop policy if exists "album_photos_select" on public.album_photos;
create policy "album_photos_select" on public.album_photos for select using ( auth.uid() is not null );
drop policy if exists "album_photos_insert" on public.album_photos;
create policy "album_photos_insert" on public.album_photos for insert with check ( auth.uid() = owner_id );
drop policy if exists "album_photos_delete" on public.album_photos;
create policy "album_photos_delete" on public.album_photos for delete using ( auth.uid() = owner_id );
