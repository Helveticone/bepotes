-- ============================================================
--  MESSAGERIE : images + réponse à un message (section 42)
--  Idempotent. À coller dans Supabase SQL Editor.
-- ============================================================
alter table public.messages add column if not exists image_url text;
alter table public.messages add column if not exists reply_to uuid references public.messages(id) on delete set null;
create index if not exists messages_reply_idx on public.messages(reply_to);
notify pgrst, 'reload schema';
