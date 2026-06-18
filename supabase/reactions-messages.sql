-- ============================================================
--  RÉACTIONS SUR LES MESSAGES (👍❤️😆😮😢🙏)
--  Une réaction par personne et par message (modifiable).
--  (Idempotent ; à relancer dans Supabase SQL Editor.)
-- ============================================================
create table if not exists public.message_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid references public.messages(id)  on delete cascade not null,
  user_id    uuid references public.profiles(id)  on delete cascade not null,
  emoji text not null,
  created_at timestamptz default now(),
  unique(message_id, user_id)
);
create index if not exists msg_react_msg_idx on public.message_reactions(message_id);
alter table public.message_reactions enable row level security;
drop policy if exists "msgreact_select" on public.message_reactions;
create policy "msgreact_select" on public.message_reactions for select using (
  exists (select 1 from public.messages m where m.id = message_id and public.is_conversation_member(m.conversation_id))
);
drop policy if exists "msgreact_insert" on public.message_reactions;
create policy "msgreact_insert" on public.message_reactions for insert with check (
  auth.uid() = user_id
  and exists (select 1 from public.messages m where m.id = message_id and public.is_conversation_member(m.conversation_id))
);
drop policy if exists "msgreact_update" on public.message_reactions;
create policy "msgreact_update" on public.message_reactions for update using ( auth.uid() = user_id );
drop policy if exists "msgreact_delete" on public.message_reactions;
create policy "msgreact_delete" on public.message_reactions for delete using ( auth.uid() = user_id );
notify pgrst, 'reload schema';
