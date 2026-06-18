-- ============================================================
--  JURAPOTES — Notifications push (Web Push / PWA)
--  À exécuter dans Supabase > SQL Editor. Idempotent.
--  ------------------------------------------------------------
--  Chaque appareil qui accepte les push enregistre un abonnement
--  (endpoint + clés). L'Edge Function « notify-push » envoie le push
--  au(x) appareil(s) du destinataire à chaque notification.
--  Voir supabase/push-GUIDE.md.
-- ============================================================
create table if not exists public.push_subscriptions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references public.profiles(id) on delete cascade not null,
  endpoint   text not null unique,
  p256dh     text not null,
  auth       text not null,
  created_at timestamptz default now()
);
create index if not exists push_subs_user_idx on public.push_subscriptions(user_id);

alter table public.push_subscriptions enable row level security;
-- Chacun ne gère que ses propres abonnements ; la fonction notify-push
-- lit via la clé service_role (RLS contournée côté serveur).
drop policy if exists "push_subs_select" on public.push_subscriptions;
create policy "push_subs_select" on public.push_subscriptions for select using ( auth.uid() = user_id );
drop policy if exists "push_subs_insert" on public.push_subscriptions;
create policy "push_subs_insert" on public.push_subscriptions for insert with check ( auth.uid() = user_id );
drop policy if exists "push_subs_update" on public.push_subscriptions;
create policy "push_subs_update" on public.push_subscriptions for update using ( auth.uid() = user_id ) with check ( auth.uid() = user_id );
drop policy if exists "push_subs_delete" on public.push_subscriptions;
create policy "push_subs_delete" on public.push_subscriptions for delete using ( auth.uid() = user_id );
