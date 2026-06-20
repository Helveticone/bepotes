-- ============================================================
--  Inscription enrichie + connexion Google (section 53)
--  Idempotent. À lancer dans Supabase → SQL Editor.
--  - profiles.gender (sexe : 'Femme' | 'Homme' | 'Autre' | 'Ne se prononce pas')
--  - handle_new_user : récupère name/full_name, town, gender, birthday, avatar
--    depuis les métadonnées (formulaire d'inscription OU fournisseur Google).
-- ============================================================

alter table public.profiles add column if not exists gender text;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare m jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  insert into public.profiles (id, name, town, gender, birthday, avatar_url)
  values (
    new.id,
    coalesce(nullif(m ->> 'name',''), nullif(m ->> 'full_name',''), 'Nouveau membre'),
    nullif(m ->> 'town',''),
    nullif(m ->> 'gender',''),
    nullif(m ->> 'birthday','')::date,
    coalesce(nullif(m ->> 'avatar_url',''), nullif(m ->> 'picture',''))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- le trigger on_auth_user_created existe déjà (schema.sql) et pointe sur cette fonction.

notify pgrst, 'reload schema';
