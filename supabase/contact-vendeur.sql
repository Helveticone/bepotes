-- ============================================================
--  BEPOTES — Contacter un vendeur (Marché) sans être amis
--  À exécuter dans Supabase > SQL Editor (après TOUT-LE-SQL.sql).
--  Sûr à ré-exécuter (idempotent).
--  ------------------------------------------------------------
--  La messagerie reste réservée aux amis PARTOUT ailleurs.
--  Cette fonction est la SEULE porte dédiée : elle crée (ou
--  retrouve) une conversation 1-à-1 entre l'utilisateur courant
--  et `other_id`, en SECURITY DEFINER (donc autorisée même hors
--  amis), et renvoie l'id de la conversation.
-- ============================================================
create or replace function public.contact_user(other_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare conv uuid;
begin
  if other_id is null or other_id = auth.uid() then
    raise exception 'destinataire invalide';
  end if;

  -- Conversation 1-à-1 existante entre les deux ?
  select c.id into conv
  from public.conversations c
  where coalesce(c.is_group, false) = false
    and exists (select 1 from public.conversation_members m
                where m.conversation_id = c.id and m.user_id = auth.uid())
    and exists (select 1 from public.conversation_members m
                where m.conversation_id = c.id and m.user_id = other_id)
    and (select count(*) from public.conversation_members m
         where m.conversation_id = c.id) = 2
  limit 1;

  if conv is not null then
    return conv;
  end if;

  -- Sinon : créer la conversation + les deux membres
  insert into public.conversations (is_group) values (false) returning id into conv;
  insert into public.conversation_members (conversation_id, user_id)
  values (conv, auth.uid()), (conv, other_id);
  return conv;
end;
$$;

grant execute on function public.contact_user(uuid) to authenticated, anon;
