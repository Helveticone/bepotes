-- ============================================================
--  BEPOTES — Suppression de compte (nLPD / droit à l'effacement)
--  À exécuter dans Supabase > SQL Editor (après TOUT-LE-SQL.sql).
--  Sûr à ré-exécuter (idempotent).
--  ------------------------------------------------------------
--  Permet à un membre de supprimer SON compte. SECURITY DEFINER :
--  la fonction (propriété de postgres) peut supprimer la ligne
--  auth.users de l'utilisateur courant. La suppression cascade
--  vers profiles -> publications, commentaires, etc. (FK on delete cascade).
-- ============================================================
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'non authentifié';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

grant execute on function public.delete_my_account() to authenticated;
