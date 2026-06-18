// ============================================================
//  JURAPOTES — Edge Function « notify-digest »
//  Envoie un RÉSUMÉ QUOTIDIEN aux membres en mode email_mode='daily'.
//  Déclenchée 1×/jour par pg_cron (voir notifications-digest-GUIDE.md).
//  ------------------------------------------------------------
//  Secrets : RESEND_API_KEY, FROM_EMAIL, SITE_URL (comme notify-email).
//  (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY injectés automatiquement.)
//
//  Déploiement :  supabase functions deploy notify-digest --no-verify-jwt
// ============================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SITE_URL = Deno.env.get("SITE_URL") || "https://jurapotes-betatest.pages.dev";
const FROM_EMAIL = Deno.env.get("FROM_EMAIL") || "Jurapotes <onboarding@resend.dev>";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") || "";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

function label(type: string): string {
  switch (type) {
    case "like": return "j'aime sur tes publications";
    case "comment": return "commentaires";
    case "mention": return "mentions";
    case "follow": return "nouveaux abonnés";
    case "message": return "messages";
    case "friend_request": return "demandes d'ami";
    case "friend_accept": return "amitiés acceptées";
    default: return "interactions";
  }
}

Deno.serve(async () => {
  try {
    if (!RESEND_API_KEY) return new Response("RESEND_API_KEY manquant", { status: 500 });

    // Membres en résumé quotidien
    const { data: dailyUsers } = await admin
      .from("profiles").select("id, name").eq("email_mode", "daily");
    if (!dailyUsers || !dailyUsers.length) return new Response("0 abonnés digest", { status: 200 });

    const since = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
    let sent = 0;

    for (const u of dailyUsers) {
      // Notifications des dernières 24 h pour ce membre
      const { data: notifs } = await admin
        .from("notifications")
        .select("type")
        .eq("user_id", u.id)
        .gte("created_at", since);
      if (!notifs || !notifs.length) continue;

      // Regroupe par type
      const counts: Record<string, number> = {};
      for (const n of notifs) counts[n.type] = (counts[n.type] || 0) + 1;
      const lines = Object.entries(counts)
        .map(([t, c]) => `<li><b>${c}</b> ${label(t)}</li>`).join("");
      const total = notifs.length;

      // E-mail du destinataire
      const { data: userRes } = await admin.auth.admin.getUserById(u.id);
      const toEmail = userRes?.user?.email;
      if (!toEmail) continue;

      const html = `
        <div style="font-family:system-ui,sans-serif;max-width:480px;margin:0 auto">
          <h2 style="color:#E11D2A;margin:0 0 12px">Jurapotes — ton résumé</h2>
          <p style="font-size:16px;color:#1A1416">Depuis hier, tu as <b>${total}</b> nouvelle${total > 1 ? "s" : ""} interaction${total > 1 ? "s" : ""} :</p>
          <ul style="font-size:15px;color:#1A1416">${lines}</ul>
          <p style="margin:22px 0">
            <a href="${SITE_URL}/notifications.html" style="background:#E11D2A;color:#fff;text-decoration:none;padding:11px 22px;border-radius:999px;font-weight:600;display:inline-block">Voir sur Jurapotes</a>
          </p>
          <p style="font-size:12px;color:#8a7d7d">Tu reçois ce résumé quotidien car tu l'as choisi dans tes Paramètres Jurapotes. Tu peux repasser en instantané ou désactiver à tout moment.</p>
        </div>`;

      const r = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { "Authorization": `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
        body: JSON.stringify({ from: FROM_EMAIL, to: toEmail, subject: `Jurapotes — ${total} nouvelle${total > 1 ? "s" : ""} interaction${total > 1 ? "s" : ""}`, html }),
      });
      if (r.ok) sent++;
    }
    return new Response(`digest envoyé à ${sent} membre(s)`, { status: 200 });
  } catch (e) {
    return new Response("error: " + (e as Error).message, { status: 500 });
  }
});
