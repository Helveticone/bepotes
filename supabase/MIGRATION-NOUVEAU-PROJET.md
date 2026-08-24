# Monter la base BePotes sur un projet Supabase vierge

Projet cible : `hshowrlrjktijmjyljys` (URL racine `https://hshowrlrjktijmjyljys.supabase.co`).

## Ordre d'exécution — 4 étapes, rien d'autre

Tout se colle dans **Supabase → SQL Editor → New query → Run**.

| # | Fichier | Pourquoi à ce rang | Rejouable ? |
|---|---|---|---|
| 1 | `schema.sql` | Crée l'extension `pgcrypto` et les **14 tables de base** (`profiles`, `follows`, `posts`, `comments`, `likes`, `events`, `event_attendees`, `groups`, `group_members`, `conversations`, `conversation_members`, `messages`, `notifications`, `reports`) + 39 policies + le trigger `on_auth_user_created`. Tout le reste s'y greffe par clé étrangère. | ❌ **Non** — `create table` / `create policy` / `create trigger` sans `if not exists` : un 2ᵉ passage échoue. À lancer une seule fois, sur base vide. |
| 2 | `storage-policies.sql` | Les 4 policies sur `storage.objects` (lecture publique, envoi dans son dossier, modification, suppression). Indépendant du reste, mais il faut avoir **créé les buckets** avant d'envoyer des fichiers. | ✅ Oui |
| 3 | `TOUT-LE-SQL.sql` | Les **sections 1 → 53** dans l'ordre : amitiés, messagerie, groupes/pages, marketplace, réactions, mentions, événements, régie pub, sondages, push, stories, albums, reels, tags photo, modération renforcée, index de perf, dashboard admin, gamification, appels manqués, confidentialité des publications… Chaque section suppose les tables de `schema.sql` déjà en place. | ✅ Oui — entièrement `if exists` / `if not exists` + `drop policy if exists` avant chaque `create policy`. |
| 4 | `devenir-admin.sql` | Te passe `is_admin = true`. **Après** l'étape 3 (la colonne `profiles.is_admin` vient de la section 6) **et après t'être inscrit sur le site** (le compte doit exister dans `auth.users`). Pense à remplacer l'e-mail en tête du fichier. | ✅ Oui |

### Avant l'étape 2 — créer les buckets Storage
Supabase → Storage → New bucket, en cochant **Public bucket** :
`avatars`, `covers`, `posts`.

### Après les 4 étapes
- `notify pgrst, 'reload schema';` est déjà appelé en fin de `TOUT-LE-SQL.sql`.
- Vérifier que `assets/config.js` pointe sur l'**URL racine** du projet (sans `/rest/v1/`) et sur la clé **anon** — jamais la `service_role`.
- Edge Functions (`notify-email`, `og-preview`, `welcome-email`, `notify-push`, `notify-digest`) : déploiement manuel, voir `DEPLOIEMENT-edge-functions.md`. L'app tourne sans.

## Les 55 autres `.sql` : à ne PAS lancer

Vérifié fichier par fichier (tables, colonnes, fonctions, policies, index) : **tous les objets qu'ils créent sont déjà repris à l'identique dans `TOUT-LE-SQL.sql`**. Ce sont les fichiers « une feature = un fichier » conservés comme historique ; les relancer ne casse rien (ils sont idempotents) mais n'apporte rien.

Couverture mesurée : 93 policies et 42 index dans `TOUT-LE-SQL.sql` — seules les 4 policies `storage.objects` de `storage-policies.sql` n'y figurent pas, d'où l'étape 2.

### Scripts ponctuels / outils — hors migration
Ceux-là ne sont pas des migrations de schéma et ne doivent surtout pas entrer dans une exécution automatique :

| Fichier | Nature |
|---|---|
| `devenir-admin.sql` | One-shot : te donner les droits admin (étape 4 ci-dessus). Contient un e-mail en dur à adapter. |
| `changer-mot-de-passe.sql` | One-shot de dépannage : réécrit `auth.users.encrypted_password` via `crypt()`. Mot de passe en clair dans le fichier — à ne jamais committer rempli. |
| `purge-contenu-demo.sql` | One-shot **destructif** : vide tout le contenu de démo (rebranding). Inutile sur une base neuve. |
| `fix-all-policies.sql`, `fixes-applied.sql` | Correctifs historiques de policies, tous absorbés par les sections 2 et 5 de `TOUT-LE-SQL.sql`. **Obsolètes.** |
| `edition.sql`, `messagerie-groupe.sql`, `ajouter-admin.sql` | Une seule policy chacun, tous absorbés (sections 14, 31, 49). **Obsolètes en tant que fichiers séparés.** |
| `index-performance.sql` | 15 index, tous repris en section 39. Redondant. |

## Points de vigilance relevés

- **`schema.sql` n'est pas idempotent** (voir tableau). Sur un projet déjà peuplé, ne pas le rejouer.
- **`schema.sql` doit passer avant tout le reste** : c'est le seul fichier qui crée `profiles`, cible de la quasi-totalité des clés étrangères (`references public.profiles(id)`).
- **Seule extension requise** : `pgcrypto` (créée par `schema.sql`), pour `gen_random_uuid()`.
- **Triggers partagés `posts` ↔ `comments`** : ne jamais référencer `NEW.post_id` dans une expression unique d'une fonction attachée aussi à `posts` → erreur `42703` qui casse toute insertion. Cf. `notify_on_mention` (section 17), déjà écrit avec un `IF TG_TABLE_NAME = 'comments'`.
- Après tout `alter table … add column`, si l'API répond `PGRST204` : `notify pgrst, 'reload schema';`.
