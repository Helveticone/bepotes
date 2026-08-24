# 🚀 BePotes — Checklist de lancement

Les étapes **manuelles** à faire (côté Supabase / Cloudflare / Google). Le code est prêt.

## 1. Base de données (Supabase) — INDISPENSABLE
- [ ] **SQL Editor** → coller et lancer **tout `supabase/TOUT-LE-SQL.sql`** d'un bloc (idempotent, sans risque).
  Active : reels, tags photos, réactions messages, modération, index perf, dashboard, chat images/réponse, monitoring.
- [ ] Se désigner **admin** si pas déjà fait (voir `supabase/devenir-admin.sql`).

## 2. Storage (Supabase) — médias
- [ ] Bucket **`posts`** : `Edit` → **File size limit** ≥ 50 Mo ; **Allowed MIME types** = vide (ou ajouter `video/mp4, video/quicktime, video/webm`). Buckets **publics**.
- [ ] (Free = 50 Mo/fichier max ; la compression vidéo navigateur ramène sous la limite.)

## 3. Domaine bepotes.be + CDN média (Cloudflare)
- [ ] Ajouter la zone **bepotes.be** à Cloudflare, brancher le projet **Pages** dessus (DNS).
- [ ] Suivre **`cloudflare/CDN-GUIDE.md`** : Worker `cdn-worker.js` + route `cdn.bepotes.be/*`.
- [ ] `assets/config.js` → `MEDIA_CDN: "https://cdn.bepotes.be"`.

## 4. Anti-bot inscription (Cloudflare Turnstile) — recommandé
- [ ] Cloudflare → Turnstile → créer un widget (domaine bepotes.be) → copier **Site Key** + **Secret Key**.
- [ ] `assets/config.js` → `TURNSTILE_SITEKEY: "<site key>"`.
- [ ] Supabase → **Authentication → Bot & Abuse Protection** → activer **Turnstile** + coller la **Secret Key**.

## 5. Garde-fous coûts (Supabase) — important
- [ ] **Spend cap** activé (par défaut sur Pro) ; **alertes de facturation** configurées.
- [ ] **Storage Image Transformations** : laissées **désactivées** (on ne s'en sert pas → pas de coût).
- [ ] (Pro) **PITR / sauvegardes** activées.

## 6. Edge Functions (optionnel — extras) — déploiement manuel CLI
- [ ] `notify-email` (Resend), `notify-digest`, `og-preview`, `notify-push` (VAPID). L'app marche sans.

## 7. SEO / découverte
- [ ] Brancher le domaine puis **Google Search Console** → soumettre `https://bepotes.be/sitemap.xml`.

## 8. Vérifs finales
- [ ] Test inscription → fil → publier (photo + vidéo) → messagerie (image + réponse) → reel.
- [ ] Dashboard admin : chiffres OK + section « Erreurs récentes » vide.
- [ ] Mobile : installation PWA, mode sombre, double-rechargement (cache instantané).
