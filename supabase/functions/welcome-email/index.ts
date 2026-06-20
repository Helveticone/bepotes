// ============================================================
//  JURAPOTES — Edge Function « welcome-email »
//  Envoie un e-mail de bienvenue à chaque NOUVEAU membre.
//  Déclenchée par un Database Webhook sur INSERT de public.profiles.
//  ------------------------------------------------------------
//  Variables d'environnement (Supabase > Edge Functions > Secrets) :
//    RESEND_API_KEY   = clé API Resend (https://resend.com)
//    FROM_EMAIL       = ex. "Jurapotes <bienvenue@tondomaine.ch>"
//    SITE_URL         = https://jurapotes-betatest.pages.dev (ou jurapotes.ch)
//  (SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY sont injectés automatiquement.)
//
//  Déploiement :  supabase functions deploy welcome-email --no-verify-jwt
//  Webhook : Database > Webhooks > New > table public.profiles, event INSERT,
//            type « Supabase Edge Functions » -> welcome-email.
//  (voir supabase/welcome-email-GUIDE.md)
// ============================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SITE_URL = Deno.env.get("SITE_URL") || "https://jurapotes-betatest.pages.dev";
const FROM_EMAIL = Deno.env.get("FROM_EMAIL") || "Jurapotes <onboarding@resend.dev>";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") || "";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

Deno.serve(async (req) => {
  try {
    const body = await req.json();
    const rec = body?.record;                 // la ligne profiles fraîchement insérée
    if (!rec || !rec.id) return new Response("no record", { status: 200 });

    // E-mail du nouveau membre (depuis auth.users)
    const { data: userRes } = await admin.auth.admin.getUserById(rec.id);
    const toEmail = userRes?.user?.email;
    if (!toEmail) return new Response("no email", { status: 200 });

    const prenom = (rec.name || "").trim().split(/\s+/)[0] || "à toi";
    const town = (rec.town || "").trim();

    const subject = "Bienvenue sur Jurapotes 👋 — le réseau du Jura";
    const html = `
      <div style="font-family:system-ui,-apple-system,Segoe UI,sans-serif;max-width:520px;margin:0 auto;color:#1A1416">
        <h2 style="color:#E11D2A;margin:0 0 6px">Bienvenue sur Jurapotes, ${prenom} 🎉</h2>
        <p style="font-size:16px;line-height:1.5">
          Te voilà sur <b>le réseau social du Jura</b>${town ? `, depuis <b>${town}</b>` : ""} !
          Ici, on retrouve ses potes, ses commerces, les événements et la vie locale — entre Jurassiens.
        </p>
        <p style="font-size:16px;margin:18px 0 8px"><b>Trois petits pas pour bien démarrer :</b></p>
        <table role="presentation" style="width:100%;border-collapse:collapse">
          <tr><td style="padding:7px 0">🧑 <a href="${SITE_URL}/profil.html" style="color:#E11D2A;font-weight:600;text-decoration:none">Complète ton profil</a> (photo + à propos)</td></tr>
          <tr><td style="padding:7px 0">🤝 <a href="${SITE_URL}/amis.html" style="color:#E11D2A;font-weight:600;text-decoration:none">Trouve des amis</a> près de chez toi</td></tr>
          <tr><td style="padding:7px 0">✍️ <a href="${SITE_URL}/fil.html" style="color:#E11D2A;font-weight:600;text-decoration:none">Publie ton premier message</a> — présente-toi au Jura !</td></tr>
        </table>
        <p style="margin:26px 0">
          <a href="${SITE_URL}/fil.html" style="background:#E11D2A;color:#fff;text-decoration:none;padding:12px 24px;border-radius:999px;font-weight:700;display:inline-block">Ouvrir Jurapotes</a>
        </p>
        <p style="font-size:13px;color:#8a7d7d;line-height:1.5">
          Astuce : installe Jurapotes sur ton téléphone (menu du navigateur → « Ajouter à l'écran d'accueil ») pour l'utiliser comme une vraie app.
        </p>
        <p style="font-size:12px;color:#b3a8a8">Tu reçois cet e-mail car tu viens de créer un compte sur Jurapotes. Tu peux gérer tes e-mails dans Paramètres.</p>
      </div>`;

    if (!RESEND_API_KEY) return new Response("RESEND_API_KEY manquant", { status: 500 });
    const r = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { "Authorization": `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: FROM_EMAIL, to: toEmail, subject, html }),
    });
    if (!r.ok) return new Response("resend error: " + (await r.text()), { status: 502 });
    return new Response("sent", { status: 200 });
  } catch (e) {
    return new Response("error: " + (e as Error).message, { status: 500 });
  }
});
