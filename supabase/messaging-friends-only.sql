-- ============================================================
--  BEPOTES — Messagerie réservée aux amis (sécurité base)
--  À exécuter dans Supabase > SQL Editor APRÈS friendships.sql.
--  Empêche, au niveau de la base, d'ajouter quelqu'un dans une
--  conversation 1-à-1 si vous n'êtes pas amis (status accepted).
-- ============================================================

-- Fonction : suis-je ami avec `other` ?
create or replace function public.are_friends(other uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.friendships
    where status = 'accepted'
      and (
        (requester_id = auth.uid() and addressee_id = other)
        or
        (requester_id = other and addressee_id = auth.uid())
      )
  );
$$;

-- On remplace la politique d'ajout de membres :
-- - je peux m'ajouter moi-même (auth.uid() = user_id)  [création de la conv]
-- - je peux ajouter quelqu'un SEULEMENT si on est amis
-- - ou si je suis déjà membre (cas conversations de groupe, plus tard)
drop policy if exists "cm_insert" on public.conversation_members;

create policy "cm_insert" on public.conversation_members
  for insert with check (
    auth.uid() = user_id
    or public.are_friends(user_id)
    or public.is_conversation_member(conversation_id)
  );

-- ============================================================
--  Pour revenir en arrière (messagerie ouverte à tous), exécuter :
--
--  drop policy if exists "cm_insert" on public.conversation_members;
--  create policy "cm_insert" on public.conversation_members
--    for insert with check (
--      auth.uid() = user_id or public.is_conversation_member(conversation_id)
--    );
-- ============================================================
