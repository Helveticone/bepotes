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

## Fil — extras récents
- **Scroll infini** : `JP.posts({before,limit})` (curseur sur `created_at`), pages de 20 via `IntersectionObserver` (sentinelle `#feedSentinel`).
- **Tri Récent/Pertinent** : bascule en haut du fil (`#feedTabs`), défaut Récent, mémorisé localStorage ; « Pertinent » = score client `fraîcheur+engagement+affinité(amis)+garde-fou<2h`.
- **Vidéos** (`posts.video_url`, `JP.uploadVideo`, `<video>` inline) et **sondages** (voir plus haut) dans le composer.
- **Aperçu de liens (OG)** : colonnes `posts.link_*` remplies à la publication par l'Edge Function `supabase/functions/og-preview` (déploiement manuel, voir guide) ; rendu carte `.link-card` (fil + post.html).
- Pubs : plusieurs encarts espacés (1ère après 3e publi, puis ~toutes les 5), ordre mélangé, 1× chacune.
- **Stories éphémères 24 h** (`stories`+`story_views`, section 29) : barre en haut du fil (`assets/stories.js`, `JPStories.mount`), création photo/vidéo+légende, visionneuse plein écran, expiration RLS 24 h.
- **Notifications push** (`push_subscriptions` section 28) : `assets/push.js` (`JPPush`), `sw-push.js` (SW sans cache), Edge Function `notify-push` (web-push+VAPID, déploiement manuel), clé `VAPID_PUBLIC` dans `config.js`. **Installation PWA** : `assets/install.js` (`JPInstall`), bouton/bannière dans Paramètres + fil.
- **Angle local** : filtre par **commune** sur fil (`posts.town`, section 30), Marché (`listings.town`) et Événements (`events.town`) ; page Événements = **agenda** groupé par date.
- **Messagerie de groupe** (section 31 : policies `cm_delete`/`conv_update`) : `JP.createGroupConversation/conversationInfo/addConversationMembers/leaveConversation/renameConversation` ; `conversations()`/`messagesOf()` gèrent groupes ; UI dans `messages.html` (bouton 👥, modale créer/gérer).
- **Profil enrichi** (sections 32-33 : `profiles.job/origin/website/birthday/show_birth_year/school/relationship`) : bloc « À propos » via `JP.aboutHTML()` (profil.html + membre.html).
- **Albums photos** (section 34 : `albums` + `album_photos`, RLS owner) : `JP.listAlbums/createAlbum/albumPhotos/addAlbumPhotos/deleteAlbum/deleteAlbumPhoto` ; onglet « Albums » sur profil.html (CRUD) et membre.html (lecture).
- **Identité** : pastille `.brand-dot` « J » dans la barre (toutes les pages).
- **Messagerie** : envoi optimiste réconcilié par texte avec l'écho temps réel (anti-doublon).
- **Galerie photos** : mosaïque façon FB (g1–g5 + « +N ») ; visionneuse `JPLightbox` navigable (flèches/swipe/clavier, compteur) dans fil.html + post.html.
- **Reels** (section 35 : `posts.is_reel`) : vidéos verticales courtes, EXCLUES du fil normal (`posts()` filtre `is_reel=false`, repli si SQL absent). `JP.reels()` (renvoie `likes`/`likedByMe`/`commentCount`)/`addReel()` ; carrousel « 🎬 Reels » avec **aperçu animé** (autoplay muet quand visible via IntersectionObserver, son au survol PC / bouton 🔊 = aperçu 5 s mobile) + tuile « + Ton reel » + lien « Voir tout › » → **page dédiée `reels.html`** (plein écran type TikTok : scroll-snap vertical, autoplay, son global, **j'aime ❤️**, suppr. de son reel, publication). Lecteur plein écran `JPReels` (autoplay, swipe ↑↓, barre d'actions ❤️). **J'aime sur les reels** = `JP.toggleLike` (table `likes`, comme les posts). Reels/suggestions groupes (`JP.suggestGroups`)/pages **intercalés** dans le fil (positions 1/4/8), pas empilés. Entrée « Reels » dans le tiroir nav.
- **Tags de personnes** (section 36 : `photo_tags` + trigger `notify_on_phototag`, notif type `phototag`) : `JP.postTags/tagPeople/untagPerson` ; ligne « 🏷️ Avec … » sous la galerie + bouton « Identifier » (auteur) dans fil.html/post.html.
- **Réactions messages** (section 37 : `message_reactions`, RLS membres) : `JP.reactMessage/messageReactions/subscribeMessageReactions`, `JP.MSG_REACTIONS` ; bouton 🙂 + sélecteur + pastilles cumulées (temps réel) dans messages.html.
- **Sous-commentaires illimités** : arbre récursif (fil.html/post.html), `Répondre` cible `data-parent=id`, indentation plafonnée (`var --cind`).
- **Modération renforcée** (section 38 : `banned_words` + `mod_queue` + trigger `flag_banned_words`, RLS `is_admin()`) : auto-signalement (sans blocage) ; `JP.listBannedWords/addBannedWord/removeBannedWord/modQueue/resolveModItem/adminDeleteComment` ; onglets Signalements/File d'attente/Mots interdits dans `panneau-hcm-7x2k9.html`.
- **Pages publiques** : `faq.html` (à tenir à jour à chaque feature), `publicite.html` (onglets Format/Formats à fournir/Tarifs/Règles — **ne jamais citer un autre réseau social** ; promotion hors annonce supprimable sans avertissement).
- **SEO** (domaine cible **jurapotes.ch**) : `robots.txt` (bloque l'espace membre + admin), `sitemap.xml`, canonical + meta description + OG/Twitter + JSON-LD (WebSite/Organization) sur les pages publiques. Pubs : insertion `insertFeedAds` idempotente + dédoublonnage + jeton anti-course.

## Reste à faire
Digest e-mail quotidien (optionnel, via `pg_cron` au lieu d'un mail par notif). Sinon : peaufinage lancement.

## Pièges connus
- Messagerie **amis-only** (RLS `cm_insert`) ; le Marché contourne via la fonction `contact_user` uniquement.
- Liste des **communes** : centralisée dans `JP.COMMUNES` / `JP.communeOptions()` (inclut Moutier, rattaché au Jura en 2026). À utiliser partout (inscription, profil, groupes, pages, marketplace, événements).
- **Cache-busting** : `theme.js` injecté dans le `<head>` (avant rendu, anti-flash) ; versions actuelles `app.supabase.js?v=80`, `style.css?v=84`, `nav.js?v=8`, `bell.js?v=23`, `theme.js?v=1`, `pwa.js?v=21`, `push.js?v=1`, `install.js?v=1`, `stories.js?v=3`. `config.js` (no-cache, pas de `?v`) contient `VAPID_PUBLIC`, `MEDIA_CDN`, `TURNSTILE_SITEKEY`, `TENOR_KEY` (tous activables au lancement).
- **Sections SQL 35-45** (ajoutées) : reels(35), tags photos(36), réactions msg(37), modération renforcée(38), index perf(39), dashboard admin+`last_seen_at`/`user_activity`(40-41), chat images/réponse(42), monitoring `client_errors`(43), chat édition/suppr+`last_read_at`/non-lus(44), **gamification(45)** (`user_stats`/`leaderboard`, scores calculés sans trigger). À lancer via `TOUT-LE-SQL.sql` (replis front prévus si non lancées).
- **Gamification & réputation** (section 45) : `JP.userStats(uid)`/`leaderboard(period,lim)` ; barème `repScore` (posts×5, reels×8, comments×2, j'aime reçus×1, amis×3, events×10, photos×1), 6 niveaux 🌱→👑 (`repLevel`), 10 badges (`earnedBadges`), `JP.reputationHTML()` réutilisable. Bloc niveau+badges sur `profil.html`/`membre.html` ; page **`classement.html`** (« Jurassien du mois » + tout-temps), entrée « Classement » dans le tiroir nav.
- **Perf/coûts** : vignettes responsives (`uploadImageWithThumb`/`JP.thumbUrl`, fil léger), fil = `comments(count)` + `JP.commentsOf` à la demande, Service Worker `sw-push.js` cache des assets versionnés, CDN média prêt (`JP.cdnUrl`+`cloudflare/`), `cacheControl` 1 an aux uploads.
- **Messagerie façon WhatsApp** : images (`messages.image_url`), réponse (`reply_to`), emojis, réactions, **édition/suppression**, **non-lus** (badge nav via bell.js + pastilles), **présence** (`heartbeat`/`conversationPresence`), **GIFs** (Tenor). Ouvre la dernière discussion à l'arrivée.
- **Lancement** : voir `LANCEMENT-CHECKLIST.md`.
- **Edge Functions à déployer manuellement** (CLI Supabase) : `notify-email` (Resend, notifs e-mail) et `og-preview` (aperçus OG). L'app fonctionne sans, juste sans ces extras.
- **Triggers PL/pgSQL partagés posts↔comments** : ne jamais référencer `NEW.post_id` dans un `CASE`/expression unique d'une fonction attachée AUSSI à `posts` (qui n'a pas ce champ) → erreur `42703 record "new" has no field "post_id"` qui casse TOUTE insertion. Utiliser un `IF TG_TABLE_NAME='comments' THEN … ELSE …` (branches compilées à l'exécution). Cf. `notify_on_mention`.
- Après un `alter table … add column`, si l'API renvoie `PGRST204 (column not in schema cache)` : `notify pgrst, 'reload schema';`.
- **`profiles` UPDATE sans `with check`** : un membre pouvait s'auto-promouvoir `is_admin`. Verrouillé par le trigger `protect_profile_privesc` (section 26 / `securite-rls.sql`) — ne pas retirer. Toute future colonne sensible sur `profiles` doit y être ajoutée.
