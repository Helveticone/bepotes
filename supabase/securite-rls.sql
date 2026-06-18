-- ============================================================
--  JURAPOTES — Durcissement sécurité RLS (avant lancement)
--  À exécuter dans Supabase > SQL Editor. Idempotent.
--  ------------------------------------------------------------
--  1) Anti-escalade de privilèges : la policy UPDATE de `profiles`
--     (using auth.uid()=id, sans WITH CHECK) permettait à un membre
--     de se mettre is_admin=true / is_banned=false sur SA ligne.
--     -> Trigger : seuls les admins peuvent changer ces 2 colonnes.
--  2) poll_votes : WITH CHECK manquant sur l'UPDATE (le vote doit
--     rester rattaché à son auteur).
-- ============================================================
create or replace function public.protect_profile_privesc()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    new.is_admin  := old.is_admin;
    new.is_banned := old.is_banned;
  end if;
  return new;
end; $$;
drop trigger if exists trg_protect_profile_privesc on public.profiles;
create trigger trg_protect_profile_privesc
  before update on public.profiles
  for each row execute function public.protect_profile_privesc();

drop policy if exists "changer son vote" on public.poll_votes;
create policy "changer son vote" on public.poll_votes for update
  using ( auth.uid() = user_id ) with check ( auth.uid() = user_id );
