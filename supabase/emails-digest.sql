-- ============================================================
--  JURAPOTES — Mode d'envoi des e-mails (instantané / quotidien / off)
--  À exécuter dans Supabase > SQL Editor. Idempotent.
--  ------------------------------------------------------------
--  email_mode :
--    'instant' (défaut) -> 1 e-mail par notification (Edge Function notify-email + webhook)
--    'daily'            -> 1 résumé par jour (Edge Function notify-digest + pg_cron)
--    'off'              -> aucun e-mail
--  Voir supabase/notifications-digest-GUIDE.md
-- ============================================================
alter table public.profiles add column if not exists email_mode text default 'instant';

-- Cohérence avec l'ancienne préférence booléenne (si elle était à false) :
update public.profiles set email_mode = 'off'
where email_mode is null and email_notifications = false;
update public.profiles set email_mode = 'instant'
where email_mode is null;
