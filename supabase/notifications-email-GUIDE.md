# Notifications par e-mail — guide d'installation

L'app envoie un e-mail au membre concerné à **chaque nouvelle notification**
(message, commentaire, mention, demande d'ami…), **sauf s'il a coupé** l'option
dans ses **Paramètres**. L'envoi se fait via une **Edge Function Supabase** +
le service **Resend** (gratuit jusqu'à 3 000 e-mails/mois, 100/jour).

> Tant que tu n'as pas fait cette installation, tout le reste fonctionne :
> la case « Recevoir les notifications par e-mail » est déjà active côté membre,
> elle attend juste l'envoi.

## 1. SQL (préférence membre)
Lance `supabase/notifications-email.sql` (ou `TOUT-LE-SQL.sql` section 23).
→ ajoute la colonne `profiles.email_notifications` (défaut : activé).

## 2. Compte Resend
1. Crée un compte sur https://resend.com (gratuit).
2. **API Keys** → crée une clé → copie-la (commence par `re_…`).
3. (Recommandé) **Domains** → ajoute `helveticonemedia.ch` (ou ton domaine) et
   valide les enregistrements DNS, pour envoyer depuis `notifications@ton-domaine`.
   Sinon tu peux démarrer avec l'expéditeur de test `onboarding@resend.dev`.

## 3. Déployer l'Edge Function
Avec le **CLI Supabase** (https://supabase.com/docs/guides/cli) :

```bash
supabase login
supabase link --project-ref TON-REF-PROJET
supabase functions deploy notify-email --no-verify-jwt
```

Le code est déjà dans `supabase/functions/notify-email/index.ts`.

> Pas de CLI ? Tu peux aussi créer la fonction dans le Dashboard
> (Edge Functions → Deploy a new function → colle le contenu du fichier).

## 4. Secrets de la fonction
Dashboard → **Edge Functions → notify-email → Secrets** (ou via CLI) :

```bash
supabase secrets set RESEND_API_KEY=re_xxxxxxxx
supabase secrets set FROM_EMAIL="Jurapotes <notifications@helveticonemedia.ch>"
supabase secrets set SITE_URL=https://jurapotes-betatest.pages.dev
```

(`SUPABASE_URL` et `SUPABASE_SERVICE_ROLE_KEY` sont fournis automatiquement.)

## 5. Database Webhook (déclencheur)
Dashboard → **Database → Webhooks → Create a new hook** :
- **Table** : `public.notifications`
- **Events** : `Insert`
- **Type** : `Supabase Edge Functions` → sélectionne `notify-email`
- **Method** : `POST` (en-têtes par défaut)

Enregistre. Désormais, chaque insertion dans `notifications` appelle la fonction,
qui envoie l'e-mail si le destinataire a gardé l'option activée.

## 6. Tester
- Avec un 2ᵉ compte, envoie-toi une demande d'ami / un message.
- Tu dois recevoir un e-mail « Jurapotes — X t'a envoyé… » avec un bouton vers le site.
- Logs en cas de souci : Dashboard → Edge Functions → notify-email → **Logs**.

## Notes
- Anti-spam : un e-mail par notification. Pour un **résumé quotidien** (digest)
  plutôt qu'un e-mail par événement, on remplacera le webhook par une tâche
  planifiée (`pg_cron`) — dis-le-moi si tu préfères ce mode.
- La préférence est respectée côté fonction (`email_notifications = false` → pas d'envoi).
