-- ============================================================
--  JURAPOTES — Correctifs appliqués en cours de route
--  Ces correctifs ont DÉJÀ été appliqués sur la base en live.
--  Ce fichier les regroupe pour garder une trace (au cas où tu
--  recrées la base un jour). À exécuter après schema.sql.
-- ============================================================

-- ---- Messagerie : politiques RLS fiables (sans "to authenticated") ----
drop policy if exists "créer une conversation" on public.conversations;
drop policy if exists "voir ses conversations" on public.conversations;
drop policy if exists "conv_insert" on public.conversations;
drop policy if exists "conv_select" on public.conversations;

create policy "conv_insert" on public.conversations
  for insert with check ( auth.uid() is not null );
create policy "conv_select" on public.conversations
  for select using ( public.is_conversation_member(id) );

drop policy if exists "s'ajouter / ajouter à une conversation" on public.conversation_members;
drop policy if exists "ajouter des participants" on public.conversation_members;
drop policy if exists "voir les membres de ses conversations" on public.conversation_members;
drop policy if exists "cm_insert" on public.conversation_members;
drop policy if exists "cm_select" on public.conversation_members;

create policy "cm_insert" on public.conversation_members
  for insert with check ( auth.uid() = user_id or public.is_conversation_member(conversation_id) );
create policy "cm_select" on public.conversation_members
  for select using ( public.is_conversation_member(conversation_id) );

drop policy if exists "lire les messages de ses conversations" on public.messages;
drop policy if exists "envoyer un message" on public.messages;
drop policy if exists "msg_insert" on public.messages;
drop policy if exists "msg_select" on public.messages;

create policy "msg_insert" on public.messages
  for insert with check ( auth.uid() = sender_id and public.is_conversation_member(conversation_id) );
create policy "msg_select" on public.messages
  for select using ( public.is_conversation_member(conversation_id) );

-- ---- Temps réel : activer la réplication ----
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.notifications;
