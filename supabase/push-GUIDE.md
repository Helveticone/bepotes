# Notifications push (Web Push / PWA) — guide d'installation

Le membre reçoit une **vraie notification** sur son téléphone/ordinateur (même
Jurapotes fermé) à chaque interaction. Il l'active depuis **Paramètres → Notifications push**.

> Tant que ce n'est pas installé, tout fonctionne : le bouton « Activer » dira
> simplement que la clé VAPID manque.

## 1. SQL
Lance `supabase/push.sql` (ou `TOUT-LE-SQL.sql` section 28) → table `push_subscriptions`.

## 2. Générer les clés VAPID (une fois)
Sur ta machine (Node installé) :
```bash
npx web-push generate-vapid-keys
```
Tu obtiens **Public Key** et **Private Key**.
- Pas de Node ? Utilise un générateur de confiance (ex. https://web-push-codelab.glitch.me/)
  — la **Public Key** n'est pas secrète ; garde la **Private Key** confidentielle.

## 3. Clé publique côté site
Édite `assets/config.js` → mets la **Public Key** dans `VAPID_PUBLIC: "..."`,
commit + push (Cloudflare redéploie). Pense à bumper le `?v=` de `config.js`… 
(config.js n'a pas de version : il est en `no-cache`, donc OK directement.)

## 4. Secrets Supabase (Edge Functions → Secrets)
```
VAPID_PUBLIC   = <Public Key>
VAPID_PRIVATE  = <Private Key>
VAPID_SUBJECT  = mailto:office@helveticonemedia.ch
```
(`SITE_URL` existe déjà.)

## 5. Déployer la fonction
```bash
supabase functions deploy notify-push --no-verify-jwt
```
(ou Dashboard → Deploy via Editor, nom `notify-push`, **Verify JWT OFF**, coller
`supabase/functions/notify-push/index.ts`.)

## 6. Webhook
Database → Webhooks → **Create a new hook** :
- Table : `public.notifications` · Events : **Insert**
- Type : **Supabase Edge Functions** → `notify-push` · POST

(C'est un 2ᵉ webhook sur `notifications`, en plus de `notify-email` — les deux
se déclenchent, c'est normal.)

## 7. Tester
1. Sur le site (HTTPS), va dans **Paramètres → Notifications push → « Activer »**,
   accepte la demande du navigateur. (Sur iPhone : il faut d'abord **ajouter
   Jurapotes à l'écran d'accueil**, le push n'est dispo qu'en mode PWA installée.)
2. Déclenche une notif (depuis un 2ᵉ compte, ou via SQL :
   `insert into public.notifications (user_id, actor_id, type) select id,id,'message' from auth.users where email='ton@email';`).
3. Une notification système doit apparaître. Logs : Edge Functions → notify-push.

## Notes
- Push ≠ e-mail : indépendants. Un membre peut avoir les deux.
- iOS : push web seulement si l'app est **installée sur l'écran d'accueil** (iOS 16.4+).
- Les abonnements expirés (404/410) sont supprimés automatiquement.
