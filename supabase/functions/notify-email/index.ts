// ============================================================
//  JURAPOTES — Edge Function « notify-email »
//  Envoie un e-mail au destinataire d'une notification.
//  Déclenchée par un Database Webhook sur INSERT de public.notifications.
//  ------------------------------------------------------------
//  Variables d'environnement (Supabase > Edge Functions > Secrets) :
//    RESEND_API_KEY   = clé API Resend (https://resend.com)
//    FROM_EMAIL       = ex. "Jurapotes <notifications@tondomaine.ch>"
//    SITE_URL         = https://jurapotes-betatest.pages.dev
//  (SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY sont injectés automatiquement.)
//
//  Déploiement :  supabase functions deploy notify-email --no-verify-jwt
//  (voir supabase/notifications-email-GUIDE.md)
// ============================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SITE_URL = Deno.env.get("SITE_URL") || "https://jurapotes-betatest.pages.dev";
const FROM_EMAIL = Deno.env.get("FROM_EMAIL") || "Jurapotes <onboarding@resend.dev>";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") || "";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

function notifText(type: string): string {
  switch (type) {
    case "like": return "a aimé ta publication";
    case "comment": return "a commenté ta publication";
    case "mention": return "t'a mentionné·e";
    case "follow": return "s'est abonné·e à toi";
    case "message": return "t'a envoyé un message";
    case "friend_request": return "t'a envoyé une demande d'ami";
    case "friend_accept": return "a accepté ta demande d'ami";
    default: return "a interagi avec toi";
  }
}
function deepLink(type: string, postId: string | null, actorId: string | null): string {
  if (type === "friend_request" || type === "friend_accept") return `${SITE_URL}/amis.html`;
  if (type === "message") return `${SITE_URL}/messages.html`;
  if (type === "follow") return actorId ? `${SITE_URL}/membre.html?id=${actorId}` : `${SITE_URL}/fil.html`;
  if ((type === "like" || type === "comment" || type === "mention") && postId) return `${SITE_URL}/post.html?id=${postId}`;
  return `${SITE_URL}/fil.html`;
}

Deno.serve(async (req) => {
  try {
    const body = await req.json();
    const rec = body?.record;
    if (!rec || !rec.user_id) return new Response("no record", { status: 200 });

    // Préférence du destinataire
    const { data: prof } = await admin
      .from("profiles")
      .select("name, email_notifications")
      .eq("id", rec.user_id)
      .single();
    if (prof && prof.email_notifications === false) {
      return new Response("opted out", { status: 200 });
    }

    // E-mail du destinataire
    const { data: userRes } = await admin.auth.admin.getUserById(rec.user_id);
    const toEmail = userRes?.user?.email;
    if (!toEmail) return new Response("no email", { status: 200 });

    // Nom de l'acteur
    let actorName = "Quelqu'un";
    if (rec.actor_id) {
      const { data: actor } = await admin.from("profiles").select("name").eq("id", rec.actor_id).single();
      if (actor?.name) actorName = actor.name;
    }

    const action = notifText(rec.type);
    const link = deepLink(rec.type, rec.post_id ?? null, rec.actor_id ?? null);
    const subject = `Jurapotes — ${actorName} ${action}`;
    const html = `
      <div style="font-family:system-ui,sans-serif;max-width:480px;margin:0 auto">
        <h2 style="color:#E11D2A;margin:0 0 12px">Jurapotes</h2>
        <p style="font-size:16px;color:#1A1416"><b>${actorName}</b> ${action}.</p>
        <p style="margin:22px 0">
          <a href="${link}" style="background:#E11D2A;color:#fff;text-decoration:none;padding:11px 22px;border-radius:999px;font-weight:600;display:inline-block">Voir sur Jurapotes</a>
        </p>
        <p style="font-size:12px;color:#8a7d7d">Tu reçois cet e-mail car les notifications sont activées dans tes Paramètres Jurapotes. Tu peux les couper à tout moment.</p>
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
