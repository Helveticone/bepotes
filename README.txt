BEPOTES — Version connectée à Supabase (réseau partagé)
==========================================================

Cette version n'est plus une démo locale : les comptes, publications,
photos, likes, commentaires et événements sont PARTAGÉS entre tous les
membres via Supabase. C'est la version à lancer.

------------------------------------------------------------
ÉTAPE 1 — METTRE TES CLÉS SUPABASE
------------------------------------------------------------
Ouvre  assets/config.js  et remplace les deux valeurs par les tiennes
(Supabase > Settings > API) :
  SUPABASE_URL  = "Project URL"        (https://xxxx.supabase.co)
  SUPABASE_ANON = "anon public" key    (longue chaîne)
Ces clés sont PUBLIQUES, prévues pour le navigateur. Ne mets JAMAIS la
clé "service_role" ici.

------------------------------------------------------------
ÉTAPE 2 — BASE DE DONNÉES (si pas déjà fait)
------------------------------------------------------------
Dans Supabase > SQL Editor, exécute dans l'ordre :
  1) schema.sql            (les tables — déjà fait normalement)
  2) storage-policies.sql  (droits sur les images)
  3) seed-events.sql       (quelques événements de démo — optionnel)

------------------------------------------------------------
ÉTAPE 3 — STORAGE (images)
------------------------------------------------------------
Dans Supabase > Storage, crée 3 buckets en cochant "Public bucket" :
  avatars   covers   posts
(puis exécute storage-policies.sql à l'étape 2 si pas déjà fait)

------------------------------------------------------------
ÉTAPE 3bis — TEMPS RÉEL (pour la messagerie)  [IMPORTANT MESSAGERIE]
------------------------------------------------------------
Pour que les messages arrivent instantanément, active la
réplication temps réel sur la table "messages" :
  Supabase > Database > Replication > (publication supabase_realtime)
  > coche la table "messages" (et "notifications" si tu veux les
    notifs en direct plus tard).
Sans ça, les messages n'apparaîtront qu'au rechargement de la page.

------------------------------------------------------------
ÉTAPE 4 — AUTH
------------------------------------------------------------
Supabase > Authentication > Providers : garder "Email" activé.
Astuce lancement : Authentication > Providers > Email, tu peux
DÉSACTIVER "Confirm email" pour que les inscriptions soient
immédiates (plus simple pour un lancement WhatsApp). Tu pourras
le réactiver plus tard pour plus de sécurité.

Pense aussi à : Authentication > URL Configuration > Site URL,
mets l'adresse de ton site (https://bepotes.be) pour que les
e-mails de confirmation pointent au bon endroit.

------------------------------------------------------------
ÉTAPE 5 — DÉPLOYER SUR CLOUDFLARE PAGES
------------------------------------------------------------
Upload tous les fichiers (index.html à la racine) comme d'habitude.
Après déploiement : Ctrl+Shift+R pour forcer le rechargement.

------------------------------------------------------------
FICHIERS
------------------------------------------------------------
  index.html         Accueil
  inscription.html   Création de compte (Supabase Auth)
  connexion.html     Connexion
  fil.html           Fil partagé : publier+photo, aimer, commenter, supprimer
  evenements.html    Événements partagés (participer)
  profil.html        Profil : photo, couverture, bio, abonnés/abonnements
  notifications.html Notifications (likes, commentaires, abonnements)
  messages.html      Messagerie privée EN TEMPS RÉEL
  amis.html          Amis : demandes reçues + liste d'amis
  recherche.html     Recherche membres + publications
  groupes.html       Liste des groupes / communautés
  groupe.html        Un groupe / une page avec son fil
  membre.html        Profil public d'un autre membre (visitable)
  pages.html         Pages d'établissement / club
  assets/config.js          <-- TES CLÉS ICI
  assets/app.supabase.js    Moteur connecté à Supabase
  assets/style.css          Styles

------------------------------------------------------------
ET APRÈS ?
------------------------------------------------------------
FAIT : abonnements (Suivre), notifications, messagerie temps réel,
RECHERCHE, DEMANDES D'AMI (boutons sur le fil + page Amis),
CRÉATION D'ÉVÉNEMENTS (bouton + sur la page Événements).
RESTE À FAIRE : pages d'établissement, modération.

SQL À EXÉCUTER (dossier supabase/) :
 - friendships.sql            -> table des amis (si pas déjà fait)
 - messaging-friends-only.sql -> messagerie réservée aux amis
 - fix-all-policies.sql       -> OPTIONNEL, à lancer SEULEMENT si les
   groupes ou le fil renvoient une erreur 403 de lecture.

NOUVEAU COMPORTEMENT :
 - On ne peut écrire qu'à ses AMIS (bouton message visible seulement
   entre amis ; double sécurité côté base).
 - Groupes : créer, rejoindre/quitter, publier dans le fil du groupe.
Les tables existent déjà dans le schéma ; on les ajoute une par une.


--- NOUVEAUTÉS (lot médias + groupes) ---
SQL À EXÉCUTER : supabase/evolutions-medias-groupes.sql
 (photos multiples, groupes ouverts/sur validation, demandes d'adhésion)

- Notifications CLIQUABLES (mènent à l'action concernée)
- Jusqu'à 6 PHOTOS par publication (fil et groupes) + agrandissement au clic
- Recherche de GROUPES (onglet dans la recherche)
- Groupes : OUVERT (rejoindre direct) ou SUR VALIDATION (demande à accepter)
- Couverture de groupe modifiable (par le créateur)
- L'owner voit et gère les demandes d'adhésion


--- NOUVEAU (profils publics + pages) ---
SQL : déjà inclus dans TOUT-LE-SQL.sql (colonnes pages).
 -> relance TOUT-LE-SQL.sql, il est sans danger à ré-exécuter.

- PROFILS PUBLICS : clique le nom/avatar de quelqu'un n'importe où
  -> sa page (photos, stats, ajouter en ami / suivre / message).
- PAGES d'établissement/club : page "Pages", créer une vitrine
  (catégorie, adresse, téléphone, site), les gens s'y ABONNENT.


--- NOUVEAU (modération & blocage) ---
SQL : relance TOUT-LE-SQL.sql (section 6 ajoutée), sans danger.
PUIS désigne-toi admin avec supabase/devenir-admin.sql
(remplace par ton email) pour accéder au tableau de bord privé
(panneau-hcm-7x2k9.html — URL secrète, non listée et non indexée).

- SIGNALER une publication ou un membre (menu ⋯ et bouton sur profil)
- BLOQUER un membre : tu ne vois plus son contenu, il ne peut plus t'écrire
  (gestion des bloqués en bas de ton profil)
- panneau-hcm-7x2k9.html : tableau de bord modération (réservé admin, URL privée)
  -> voir les signalements, supprimer un post, bannir, traiter/rejeter


--- NOUVEAU (galerie photos profil) ---
Pas de SQL à lancer (la galerie agrège les photos déjà publiées).
- Onglets Publications / Photos sur ton profil ET sur les profils publics.
- La galerie rassemble automatiquement toutes les photos de tes posts.
- Clic sur une photo = agrandissement (lightbox).


--- NOUVEAU (bannissement réel + PWA mobile) ---
Pas de nouveau SQL (is_banned existe déjà).

BANNISSEMENT : un membre banni depuis l'admin est maintenant
déconnecté et redirigé vers banni.html ; il ne peut plus accéder au site.

PWA (application installable) :
 - Nouveaux fichiers : manifest.json, sw.js, offline.html, dossier icons/
 - Sur mobile, les visiteurs peuvent "Ajouter à l'écran d'accueil" et
   utiliser BePotes comme une vraie app (plein écran, icône).
 - IMPORTANT déploiement : uploade bien manifest.json, sw.js, offline.html
   ET le dossier icons/ à la racine, en plus des HTML et assets.
 - La PWA exige HTTPS (Cloudflare Pages le fournit déjà).
