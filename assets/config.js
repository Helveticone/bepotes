/* ============================================================
   CONFIGURATION SUPABASE
   ------------------------------------------------------------
   Clés du projet Jurapotes (clés PUBLIQUES, prévues pour le
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
  // directement par Supabase). Au lancement, mets ex. "https://cdn.jurapotes.ch"
  // (voir cloudflare/cdn-worker.js + cloudflare/CDN-GUIDE.md). Aucun autre changement requis.
  MEDIA_CDN: ""
};
