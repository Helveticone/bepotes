# Jurapotes — guide projet (pour Claude)

Réseau social **local du canton du Jura (Suisse)**, façon Facebook, réservé aux habitants.
Site **statique** (HTML/CSS/JS) + **Supabase** (Postgres + Auth + Storage + Realtime).

## Stack & déploiement
- **Front** : pages `.html` à la racine + `assets/` (`app.supabase.js`, `nav.js`, `style.css`, `config.js`, `bell.js`, `moderation.js`, `pwa.js`, `supabase.min.js`).
- **Back** : Supabase. Clé **anon** publique dans `assets/config.js` (normal ; la sécurité = **RLS**). JAMAIS de clé service_role côté client.
- **Hébergement** : Cloudflare Pages, **déploiement auto à chaque push sur `main`**. Repo : `Helveticone/jurapotes`. Prod : https://jurapotes-betatest.pages.dev
- Pas de build. `sw.js` est neutralisé (se désinstalle).

## Architecture front
- `assets/app.supabase.js` = module global **`window.JP`** (toute la logique données + helpers). Exporte ~tout en bas (`return {...}`).
- Chaque page : `requireAuth()` puis rend via les fonctions `JP.*`. UI rendue en template strings + `addEventListener`.
- `assets/nav.js` = menu mobile centralisé (☰ haut + onglet « Menu » bas → tiroir gauche). Inclus sur les pages connectées.
- Avatars : `JP.avatarHTML(name, avatar, cls, style)`. Échappement : `JP.esc()`. Mentions : `JP.mentionHTML()`.

## Conventions IMPORTANTES
- **Cache-busting** : à chaque modif de `style.css`/`app.supabase.js`/`nav.js`, **bumper le `?v=N`** dans TOUTES les pages (sed sur `*.html`). Sinon les users gardent l'ancien (assets en cache 1 h via `_headers`).
- **SQL** : tout va dans `supabase/TOUT-LE-SQL.sql` (idempotent, sections numérotées, à relancer en bloc après `schema.sql`). Fichiers individuels aussi dans `supabase/`. Toute policy `create` doit être précédée d'un `drop policy if exists` du MÊME nom (idempotence). RLS = toujours `auth.uid()` (jamais `auth.role()='authenticated'`).
- **Mobile** : pas de débordement horizontal. Tester avec un banc d'essai headless (puppeteer-core + Chrome) reproduisant le markup, mesurer `bodyScrollW` vs `docW` à 320/360/390px. node_modules + `_*` (bancs d'essai) sont gitignored.
- **Workflow** : 1 feature = 1 commit + push (Cloudflare redéploie). Messages de commit en FR, trailer `Co-Authored-By: Claude...`.
- Permissions Claude Code auto-allow : `.claude/settings.local.json` (gitignored).

## Modèle de données (Supabase, tables publiques)
profiles, follows, friendships, posts (+ images[], shared_post_id, group_id), comments (+ parent_id), likes (+ type=réaction), comment_likes, events (+ status via event_attendees, event_comments), event_attendees, groups (+ kind=group|page, rules, is_private, category/address/phone/website), group_members (role=owner|admin|member|pending), conversations, conversation_members, messages, notifications, reports, blocks, listings (marketplace), page_reviews.
Fonctions clés (SECURITY DEFINER) : `is_conversation_member`, `are_friends`, `is_group_manager`, `protect_group_owner` (trigger), `is_admin`, `contact_user`, `friend_suggestions`, `notify_on_*` (triggers).

## Fonctionnalités déjà en place
Auth, profils (avatar/couverture recadrables), fil (posts multi-photos, réactions 👍❤️😆😮😢, commentaires façon FB : aperçu/voir tous/tri/like/**réponses 1 niveau**/édition, **@mentions** autocomplétion+notif), permalien `post.html`, **repartage**, **sondages** 📊 (`posts.poll_options`+`poll_votes`, vote/retrait, fil+post.html), amis + abonnements, **suggestions d'amis** (amis communs), groupes + **pages** (admins, règles, couverture, avis ⭐), **marketplace** (`marketplace.html`, contact vendeur), **événements** (`evenements.html`/`evenement.html` : Intéressé+participe, discussion), messagerie temps réel (amis only + contact vendeur), notifications (cliquables), **page Paramètres** (`parametres.html` : e-mail, mot de passe, suppression nLPD, pref e-mails), **mode sombre** 🌙 (`assets/theme.js`+`JPTheme`, bascule dans nav.js, palette `[data-theme=dark]`), recherche, modération/blocage/admin, PWA, menu mobile (tiroir).
- **Régie publicitaire** (admin) : table `ads` + `active_ads(device)`/`ad_impression`/`ad_click` ; carte « Sponsorisé » dans le fil (image PC/mobile + texte, lien interne/externe, rotation aléatoire, plafond mensuel, affichages+clics+CTR). Gérée via `regie-hcm-7x2k9.html` (drag&drop+▲▼).
- **Notifications e-mail** : pref `profiles.email_notifications` ; envoi via Edge Function `supabase/functions/notify-email` (Resend) + Database Webhook sur `notifications` — voir `supabase/notifications-email-GUIDE.md` (à déployer manuellement).

## Pages admin (URL privées, NON listées, `noindex`)
- `panneau-hcm-7x2k9.html` = modération (ex-`admin.html`). `regie-hcm-7x2k9.html` = régie pub (ex-`admin-pub.html`).
- **Aucun lien dans le menu** (volontaire). Vraie sécurité = RLS `is_admin()`. Devenir admin : `supabase/devenir-admin.sql` (compte `office@helveticonemedia.ch`).

## Reste à faire (priorité « confort / lancement »)
Aperçu de liens (OG), vidéos, pagination/scroll infini. (Optionnel : digest e-mail quotidien via `pg_cron` au lieu d'un mail/notif.)

## Pièges connus
- Messagerie **amis-only** (RLS `cm_insert`) ; le Marché contourne via la fonction `contact_user` uniquement.
- Liste des **communes** : centralisée dans `JP.COMMUNES` / `JP.communeOptions()` (inclut Moutier, rattaché au Jura en 2026). À utiliser partout (inscription, profil, groupes, pages, marketplace, événements).
- **Cache-busting** : `theme.js` injecté dans le `<head>` (avant rendu, anti-flash) ; versions actuelles `app.supabase.js?v=39`, `style.css?v=43`, `nav.js?v=4`, `bell.js?v=22`, `theme.js?v=1`.
