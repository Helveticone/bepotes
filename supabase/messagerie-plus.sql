-- ============================================================
--  MESSAGERIE + : édition/suppression de message + lus/non-lus (section 44)
--  Idempotent. À coller dans Supabase SQL Editor.
-- ============================================================

-- Édition / suppression de SES propres messages
alter table public.messages add column if not exists edited_at timestamptz;
drop policy if exists "msg_update" on public.messages;
create policy "msg_update" on public.messages for update
  using ( auth.uid() = sender_id ) with check ( auth.uid() = sender_id );
drop policy if exists "msg_delete" on public.messages;
create policy "msg_delete" on public.messages for delete
  using ( auth.uid() = sender_id );

-- Suivi des messages lus (dernière lecture par membre/conversation)
alter table public.conversation_members add column if not exists last_read_at timestamptz;

-- Marquer une conversation comme lue (RPC : pas de policy UPDATE large = pas d'escalade de rôle)
create or replace function public.mark_conversation_read(conv uuid)
returns void language sql security definer set search_path = public as $$
  update public.conversation_members set last_read_at = now()
  where conversation_id = conv and user_id = auth.uid();
$$;
grant execute on function public.mark_conversation_read(uuid) to authenticated;

-- Nombre de messages non lus par conversation (pour le membre courant)
create or replace function public.unread_by_conversation()
returns table(conversation_id uuid, n int)
language sql security definer set search_path = public as $$
  select m.conversation_id, count(*)::int
  from public.messages m
  join public.conversation_members cm
    on cm.conversation_id = m.conversation_id and cm.user_id = auth.uid()
  where m.sender_id <> auth.uid()
    and (cm.last_read_at is null or m.created_at > cm.last_read_at)
  group by m.conversation_id;
$$;
grant execute on function public.unread_by_conversation() to authenticated;
