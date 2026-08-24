/* ============================================================
   CONFIGURATION SUPABASE
   ------------------------------------------------------------
   Clés du projet BePotes (clés PUBLIQUES, prévues pour le
   navigateur ; la sécurité vient de la RLS, pas du secret).
   Ne mets JAMAIS la clé "service_role" ici.
   ============================================================ */

window.JP_CONFIG = {
  SUPABASE_URL:  "https://nvlquqrsjmwgtkhmxazq.supabase.co",
  SUPABASE_ANON: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52bHF1cXJzam13Z3RraG14YXpxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2MDA1ODAsImV4cCI6MjA5NzE3NjU4MH0.p-D6FAH2jTTCFWhcrI8NwpOrkYH2ImwBGxZrprIw0K0",
  // Notifications push : clé PUBLIQUE VAPID (générée via `npx web-push generate-vapid-keys`).
  // Colle ici la "Public Key" ; la clé privée va dans les secrets Supabase (voir push-GUIDE.md).
  VAPID_PUBLIC: "BDQ6phxYy7ryVbMKWjqfztaBvRUT28m28jVN_rYTpF9_nk7AAHnJ8z7Bn2Jnmt5ln3K4J4RKNNlXGSCLoaOsB8g",

  // CDN média (Cloudflare devant Supabase Storage). VIDE = désactivé (médias servis
  // directement par Supabase). Worker actif sur workers.dev (provisoire avant BePotes.ch).
  // Quand BePotes.ch sera branché : remplacer par "https://cdn.BePotes.ch".
  // (voir cloudflare/cdn-worker.js + cloudflare/CDN-GUIDE.md). Aucun autre changement requis.
  MEDIA_CDN: "https://BePotes.connect41swiss1.workers.dev",

  // Anti-bot à l'inscription : clé PUBLIQUE Cloudflare Turnstile (gratuit).
  // VIDE = désactivé (seule la protection honeypot/délai s'applique). Pour activer :
  // 1) créer un widget Turnstile (dashboard Cloudflare) → coller la "Site Key" ici ;
  // 2) Supabase → Authentication → Bot & Abuse Protection → activer Turnstile + coller la "Secret Key".
  TURNSTILE_SITEKEY: "",

  // GIFs dans le chat (Tenor, gratuit). VIDE = bouton GIF masqué. Pour activer :
  // créer une clé sur Google Cloud (API « Tenor ») → la coller ici. Recherche filtrée SFW.
  TENOR_KEY: "",

  // Connexion Google (OAuth). false = bouton « Continuer avec Google » masqué.
  // Passer à true UNE FOIS le provider Google activé dans Supabase
  // (Authentication → Providers → Google). Voir supabase/google-auth-GUIDE.md.
  GOOGLE_AUTH: true
};

