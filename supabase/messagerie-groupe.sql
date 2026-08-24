-- ============================================================
--  BEPOTES — Messagerie de groupe (policies complémentaires)
--  À exécuter dans Supabase > SQL Editor. Idempotent.
--  ------------------------------------------------------------
--  Le schéma gère déjà les groupes (conversations.is_group + title).
--  Il manquait : pouvoir QUITTER (delete sur conversation_members)
--  et RENOMMER (update sur conversations) — réservés aux membres.
-- ============================================================
drop policy if exists "cm_delete" on public.conversation_members;
create policy "cm_delete" on public.conversation_members for delete
  using ( auth.uid() = user_id );

drop policy if exists "conv_update" on public.conversations;
create policy "conv_update" on public.conversations for update
  using ( public.is_conversation_member(id) )
  with check ( public.is_conversation_member(id) );
