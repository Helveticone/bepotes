# Déploiement des Edge Functions — runbook complet

3 fonctions :
- **notify-email** : 1 e-mail par notification (mode « instant »).
- **notify-digest** : 1 résumé par jour (mode « daily »), planifié par pg_cron.
- **og-preview** : aperçu de liens (appelée par le front à la publication).

Tout fonctionne sans elles ; elles ajoutent e-mails + aperçus de liens.

---

## 0. Pré-requis (une fois)
1. **Compte Resend** (gratuit) : https://resend.com → API Keys → copie `re_…`.
   (Recommandé : valider ton domaine pour expédier depuis `notifications@helveticonemedia.ch`.)
2. **CLI Supabase** : https://supabase.com/docs/guides/cli/getting-started
   ```bash
   supabase login
   supabase link --project-ref <PROJECT_REF>
   ```
   `<PROJECT_REF>` = l'identifiant du projet (Dashboard → Settings → General, ou dans l'URL `https://<PROJECT_REF>.supabase.co`).

## 1. SQL (si pas déjà fait)
Dans SQL Editor, relance **`TOUT-LE-SQL.sql`** (couvre les sections 22-27 :
sondages, e-mails, vidéos, aperçus, sécurité, email_mode).

## 2. Secrets (communs aux fonctions e-mail)
```bash
supabase secrets set RESEND_API_KEY=re_xxxxxxxx
supabase secrets set FROM_EMAIL="Jurapotes <notifications@helveticonemedia.ch>"
supabase secrets set SITE_URL=https://jurapotes-betatest.pages.dev
```
(`SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` sont fournis automatiquement.)

## 3. Déployer les 3 fonctions
```bash
supabase functions deploy notify-email  --no-verify-jwt
supabase functions deploy notify-digest --no-verify-jwt
supabase functions deploy og-preview
```
> `og-preview` est appelée par le front avec le jeton de session : laisse la
> vérification JWT par défaut (ne mets PAS `--no-verify-jwt`).

> Sans CLI : Dashboard → Edge Functions → Deploy a new function → colle le
> contenu de `supabase/functions/<nom>/index.ts`.

## 4. Webhook pour l'instantané (notify-email)
Dashboard → **Database → Webhooks → Create a new hook** :
- Table : `public.notifications`
- Events : **Insert**
- Type : **Supabase Edge Functions** → `notify-email`
- Method : POST

## 5. Cron pour le digest (notify-digest)
SQL Editor (remplace `<PROJECT_REF>` et `<SERVICE_ROLE_KEY>` — Settings → API) :
```sql
create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
  'jurapotes-digest-quotidien',
  '0 7 * * *',                       -- 07:00 UTC (~08-09h en Suisse)
  $$
  select net.http_post(
    url     := 'https://<PROJECT_REF>.functions.supabase.co/notify-digest',
    headers := jsonb_build_object('Content-Type','application/json',
               'Authorization','Bearer <SERVICE_ROLE_KEY>'),
    body    := '{}'::jsonb
  );
  $$
);
```

## 6. Tests
- **Aperçu de liens** : publie un post avec une URL d'article → carte affichée.
- **E-mail instantané** : avec un 2ᵉ compte (en mode « À chaque notification »),
  envoie-lui une demande d'ami → il reçoit un e-mail.
- **Digest** : mets un compte en « Résumé quotidien », génère-lui une notif, puis
  ```bash
  curl -X POST 'https://<PROJECT_REF>.functions.supabase.co/notify-digest' \
    -H 'Authorization: Bearer <SERVICE_ROLE_KEY>'
  ```
  → réponse `digest envoyé à N membre(s)`.

Logs en cas de souci : Dashboard → Edge Functions → (la fonction) → Logs.

---

### Récap des fichiers
- `supabase/functions/notify-email/index.ts` + `notifications-email-GUIDE.md`
- `supabase/functions/notify-digest/index.ts` + `notifications-digest-GUIDE.md`
- `supabase/functions/og-preview/index.ts` + `apercu-liens-GUIDE.md`
