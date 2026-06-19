-- ============================================================
--  MONITORING — journal des erreurs côté client (section 43)
--  L'app envoie ici les erreurs JS rencontrées par les membres ;
--  visibles dans le dashboard admin. Insertion par le membre concerné,
--  lecture/suppression réservées aux admins. (Idempotent.)
-- ============================================================
create table if not exists public.client_errors (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  message text,
  source  text,    -- page (chemin)
  detail  text,    -- pile / infos
  ua      text,    -- navigateur
  created_at timestamptz default now()
);
create index if not exists client_errors_created_idx on public.client_errors(created_at desc);
alter table public.client_errors enable row level security;
drop policy if exists "cerr_insert" on public.client_errors;
create policy "cerr_insert" on public.client_errors for insert with check ( auth.uid() = user_id );
drop policy if exists "cerr_select" on public.client_errors;
create policy "cerr_select" on public.client_errors for select using ( public.is_admin() );
drop policy if exists "cerr_delete" on public.client_errors;
create policy "cerr_delete" on public.client_errors for delete using ( public.is_admin() );
notify pgrst, 'reload schema';
