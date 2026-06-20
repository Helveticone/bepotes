# E-mail de bienvenue — guide de déploiement

Envoie automatiquement un e-mail chaleureux à **chaque nouveau membre** (déclenché à la création du profil). Réutilise les mêmes secrets Resend que `notify-email`.

## 1. Prérequis (déjà fait si `notify-email` tourne)
Dans **Supabase → Edge Functions → Secrets**, ces 3 secrets doivent exister :
- `RESEND_API_KEY` — clé API [Resend](https://resend.com)
- `FROM_EMAIL` — ex. `Jurapotes <bienvenue@jurapotes.ch>` (⚠️ domaine **vérifié** dans Resend pour envoyer à de vraies adresses ; sinon `onboarding@resend.dev` n'envoie qu'à TA propre adresse Resend en test)
- `SITE_URL` — `https://jurapotes-betatest.pages.dev` (ou `https://jurapotes.ch`)

(`SUPABASE_URL` et `SUPABASE_SERVICE_ROLE_KEY` sont injectés automatiquement.)

## 2. Déployer la fonction
```bash
supabase functions deploy welcome-email --no-verify-jwt
```

## 3. Brancher le Database Webhook
Supabase → **Database → Webhooks → Create a new hook** :
- **Table** : `public.profiles`
- **Events** : `Insert` (uniquement)
- **Type** : `Supabase Edge Functions` → choisir **welcome-email**
- (méthode POST, le webhook envoie `{ record: <profil inséré> }`)

Enregistre. ✅

## 4. Tester
- Inscris un nouveau compte de test → l'e-mail de bienvenue doit arriver dans la minute.
- Pas reçu ? Edge Functions → **welcome-email → Logs** : tu verras `sent`, `no email`, ou l'erreur Resend (souvent un domaine `FROM_EMAIL` non vérifié).

## Notes
- N'affecte **que les nouveaux inscrits** (le webhook ne se déclenche pas pour les 24 membres existants — voulu, pas de spam rétroactif).
- Indépendant des préférences e-mail de notification (un mail de bienvenue est transactionnel, envoyé une seule fois).
- Le webhook sur `profiles` se déclenche après le trigger `handle_new_user` (le profil est déjà créé avec `name`/`town`).
