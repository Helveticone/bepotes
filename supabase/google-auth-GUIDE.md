# Connexion Google (OAuth) — guide d'activation

Permet de s'inscrire / se connecter en 1 clic avec un compte Google.
Tout le code est prêt ; il reste 3 étapes de config (≈ 10 min).

## 1. Identifiants Google (Google Cloud Console)
1. Va sur https://console.cloud.google.com/ → crée un projet (ex. « BePotes »).
2. **APIs & Services → OAuth consent screen** : type **External**, renseigne le nom
   « BePotes », un e-mail de support, le domaine. Publie (ou laisse en test au début).
3. **APIs & Services → Credentials → Create Credentials → OAuth client ID** :
   - Type : **Web application**.
   - **Authorized redirect URIs** : ajoute l'URL de callback Supabase :
     `https://nvlquqrsjmwgtkhmxazq.supabase.co/auth/v1/callback`
   - Crée → note le **Client ID** et le **Client Secret**.

## 2. Activer le provider dans Supabase
Supabase → **Authentication → Providers → Google** :
- Active le provider, colle le **Client ID** et le **Client Secret**.
- Enregistre.

(Optionnel mais conseillé : Authentication → URL Configuration → **Site URL** =
`https://bepotes-betatest.pages.dev` (puis `https://bepotes.be`), et ajoute les deux
dans **Redirect URLs**.)

## 3. SQL (une fois)
Lance `supabase/inscription-enrichie.sql` (section 53) dans le SQL Editor :
- ajoute la colonne `profiles.gender` ;
- met à jour `handle_new_user` pour récupérer nom / commune / sexe / date de naissance /
  **photo de profil Google** depuis les métadonnées.

## 4. Activer le bouton côté app
Dans `assets/config.js`, passe :
```js
GOOGLE_AUTH: true
```
→ le bouton « Continuer avec Google » apparaît sur connexion.html et inscription.html.
(config.js est en no-cache : effet immédiat après push.)

## Comment ça marche
- Clic « Continuer avec Google » → connexion Google → retour sur `fil.html`.
- Le trigger crée le profil avec le **nom + photo Google**, mais **sans commune**.
- `requireAuth` détecte l'absence de commune et redirige vers **`bienvenue.html`**
  (commune obligatoire + sexe + date de naissance) avant d'entrer dans l'app.

## Notes
- Tant que `GOOGLE_AUTH` est `false`, rien ne change (bouton masqué).
- Réversible : repasser `GOOGLE_AUTH` à `false` masque le bouton.
- Apple Sign-In : à ajouter quand l'app native iOS sera faite (exigé par Apple).
