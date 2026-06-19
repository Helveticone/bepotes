# CDN média — Cloudflare devant Supabase Storage

But : faire servir les images/vidéos par **Cloudflare** (egress gratuit) au lieu de
Supabase (egress facturé). À activer **une fois `jurapotes.ch` branché sur Cloudflare**.

Tout est déjà prêt côté app : un helper `JP.cdnUrl()` réécrit les URL média vers le CDN
**dès que** `MEDIA_CDN` est renseigné dans `assets/config.js`. Tant que c'est vide → aucun effet.

## Étapes (≈ 5 min, le jour du branchement du domaine)

1. **Ajouter le domaine `jurapotes.ch`** à ton compte Cloudflare (zone) et faire pointer les
   DNS (le site reste sur Cloudflare Pages). Brancher aussi `jurapotes.ch` au projet Pages.

2. **DNS** : créer un enregistrement **`cdn`** (type AAAA `100::` ou CNAME vers le domaine),
   en mode **Proxy activé (nuage orange)**. → `cdn.jurapotes.ch`.

3. **Créer le Worker** : Cloudflare → *Workers & Pages* → *Create Worker* → coller le contenu
   de `cloudflare/cdn-worker.js`. Vérifier la ligne `SUPABASE_ORIGIN` (déjà ton projet).
   *Deploy*.

4. **Route du Worker** : dans le Worker → *Settings* → *Domains & Routes* → *Add route* :
   `cdn.jurapotes.ch/*` (zone `jurapotes.ch`).

5. **Vérifier** : ouvre dans le navigateur
   `https://cdn.jurapotes.ch/storage/v1/object/public/posts/...` (une URL d'image existante,
   en remplaçant le host). L'image doit s'afficher, avec l'en-tête `X-Jurapotes-CDN: 1`
   (2ᵉ chargement = `cf-cache-status: HIT`).

6. **Activer côté app** : dans `assets/config.js`, mettre
   `MEDIA_CDN: "https://cdn.jurapotes.ch"`. (Pas de `?v` sur config.js : pris en compte direct.)
   → toutes les nouvelles vues média passent par le CDN.

## Notes
- **Garder les buckets Storage en PUBLIC** (sinon le Worker ne peut pas lire).
- Aucune migration de données : on ne réécrit que l'**affichage** des URL (les fichiers
  restent sur Supabase). Réversible instantanément (revider `MEDIA_CDN`).
- Le cache navigateur (1 an, déjà en place) couvre les vues d'un même utilisateur ; le CDN
  ajoute le cache **mutualisé** entre tous les visiteurs.
- Option sans Worker (Transform Rule/Cache Rule) possible mais le Worker est le plus simple
  et le plus robuste.
