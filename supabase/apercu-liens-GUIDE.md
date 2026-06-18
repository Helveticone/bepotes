# Aperçu de liens (Open Graph) — guide d'installation

Quand un membre colle une URL dans une publication, Jurapotes affiche une
**carte d'aperçu** (titre, description, image, site). Les métadonnées sont
récupérées **une seule fois à la publication** par une Edge Function (le
navigateur ne peut pas lire un autre site à cause du CORS), puis **stockées
sur le post**.

> Tant que ce n'est pas déployé, tout fonctionne : on publie normalement,
> il n'y a simplement pas de carte d'aperçu.

## 1. SQL
Lance `supabase/apercu-liens.sql` (ou `TOUT-LE-SQL.sql` section 25).
→ ajoute les colonnes `link_url / link_title / link_desc / link_image / link_site`.

## 2. Déployer l'Edge Function
Code déjà présent dans `supabase/functions/og-preview/index.ts`.

```bash
supabase login
supabase link --project-ref TON-REF-PROJET
supabase functions deploy og-preview
```

> Pas de CLI ? Dashboard → Edge Functions → Deploy a new function →
> nomme-la `og-preview` et colle le contenu du fichier.

Aucun secret à configurer. La fonction est appelée par le front via
`sb.functions.invoke('og-preview', { body:{ url } })` (le jeton de session
est transmis automatiquement).

## 3. Tester
- Publie un post contenant une URL (ex. un article de presse, un lien YouTube).
- La carte (titre + image + site) doit apparaître sous le texte.
- Logs : Dashboard → Edge Functions → og-preview → Logs.

## Notes
- L'aperçu est figé au moment de la publication (pas de re-fetch ensuite).
- Si le site ciblé ne fournit pas de balises Open Graph, aucune carte n'est
  affichée (on ne montre pas d'aperçu vide).
