-- ============================================================
--  JURAPOTES — Notifications par e-mail (préférence membre)
--  À exécuter dans Supabase > SQL Editor. Idempotent.
--  ------------------------------------------------------------
--  Ajoute une préférence par membre : recevoir (ou non) un e-mail
--  à chaque notification. L'ENVOI est assuré par l'Edge Function
--  « notify-email » + un Database Webhook (voir le guide
--  supabase/notifications-email-GUIDE.md).
-- ============================================================
alter table public.profiles
  add column if not exists email_notifications boolean default true;
