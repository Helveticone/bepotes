# Résumé e-mail quotidien (digest) — guide d'installation

Chaque membre choisit dans ses **Paramètres** : *À chaque notification* (instantané),
*Un résumé par jour* (digest) ou *Désactivées*. Le digest envoie **un seul e-mail
par jour** récapitulant les interactions des dernières 24 h.

> Pré-requis : avoir déjà mis en place l'e-mail instantané (compte Resend +
> secrets `RESEND_API_KEY` / `FROM_EMAIL` / `SITE_URL`). Voir
> `notifications-email-GUIDE.md`.

## 1. SQL
Lance `supabase/emails-digest.sql` (ou `TOUT-LE-SQL.sql` section 27).
→ ajoute `profiles.email_mode` ('instant' | 'daily' | 'off').

> La fonction instantanée `notify-email` a été mise à jour pour n'envoyer que si
> `email_mode='instant'` — **redéploie-la** : `supabase functions deploy notify-email --no-verify-jwt`.

## 2. Déployer la fonction digest
Code dans `supabase/functions/notify-digest/index.ts`.

```bash
supabase functions deploy notify-digest --no-verify-jwt
```
(Mêmes secrets que notify-email, déjà configurés.)

## 3. Planifier l'envoi quotidien (pg_cron + pg_net)
Dans **Supabase → SQL Editor** (active les extensions si besoin) :

```sql
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Remplace <PROJECT_REF> et <SERVICE_ROLE_KEY> (Settings > API).
-- Tous les jours à 08:00 (heure du serveur, UTC).
select cron.schedule(
  'jurapotes-digest-quotidien',
  '0 8 * * *',
  $$
  select net.http_post(
    url     := 'https://<PROJECT_REF>.functions.supabase.co/notify-digest',
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'Authorization','Bearer <SERVICE_ROLE_KEY>'
    ),
    body    := '{}'::jsonb
  );
  $$
);
```

> Pour changer l'heure : `cron.schedule` réécrit le job du même nom.
> Pour supprimer : `select cron.unschedule('jurapotes-digest-quotidien');`

## 4. Tester sans attendre 8 h
Appelle la fonction à la main (un membre doit être en mode « daily » et avoir
reçu au moins une notification dans les dernières 24 h) :

```bash
curl -X POST 'https://<PROJECT_REF>.functions.supabase.co/notify-digest' \
  -H 'Authorization: Bearer <SERVICE_ROLE_KEY>'
```
Réponse attendue : `digest envoyé à N membre(s)`. Logs : Dashboard → Edge Functions → notify-digest.

## Notes
- L'instantané et le digest sont **exclusifs** (selon `email_mode`).
- Le résumé compte les notifications des dernières 24 h, regroupées par type.
- Fuseau : le cron est en UTC. Pour 08:00 en Suisse (UTC+1/+2), mets `'0 7 * * *'`
  (hiver) ou `'0 6 * * *'` (été), ou garde 08:00 UTC, peu importe pour un digest.
