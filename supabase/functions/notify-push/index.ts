// ============================================================
//  JURAPOTES — Edge Function « notify-push »
//  Envoie une notification push aux appareils du destinataire.
//  Déclenchée par un Database Webhook sur INSERT de public.notifications.
//  ------------------------------------------------------------
//  Secrets : VAPID_PUBLIC, VAPID_PRIVATE, VAPID_SUBJECT (ex. mailto:office@helveticonemedia.ch),
//            SITE_URL. (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY auto.)
//  Déploiement : supabase functions deploy notify-push --no-verify-jwt
//  (voir supabase/push-GUIDE.md)
// ============================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

const SITE_URL = Deno.env.get("SITE_URL") || "https://jurapotes-betatest.pages.dev";
const VAPID_PUBLIC = Deno.env.get("VAPID_PUBLIC") || "";
const VAPID_PRIVATE = Deno.env.get("VAPID_PRIVATE") || "";
const VAPID_SUBJECT = Deno.env.get("VAPID_SUBJECT") || "mailto:office@helveticonemedia.ch";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

if (VAPID_PUBLIC && VAPID_PRIVATE) {
  webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE);
}

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
  if (type === "friend_request" || type === "friend_accept") return "/amis.html";
  if (type === "message") return "/messages.html";
  if (type === "follow") return actorId ? "/membre.html?id=" + actorId : "/fil.html";
  if ((type === "like" || type === "comment" || type === "mention") && postId) return "/post.html?id=" + postId;
  return "/fil.html";
}

Deno.serve(async (req) => {
  try {
    if (!VAPID_PUBLIC || !VAPID_PRIVATE) return new Response("VAPID manquant", { status: 500 });
    const body = await req.json();
    const rec = body?.record;
    if (!rec || !rec.user_id) return new Response("no record", { status: 200 });

    const { data: subs } = await admin
      .from("push_subscriptions").select("endpoint, p256dh, auth").eq("user_id", rec.user_id);
    if (!subs || !subs.length) return new Response("no subs", { status: 200 });

    let actorName = "Quelqu'un";
    if (rec.actor_id) {
      const { data: actor } = await admin.from("profiles").select("name").eq("id", rec.actor_id).single();
      if (actor?.name) actorName = actor.name;
    }

    const payload = JSON.stringify({
      title: "Jurapotes",
      body: `${actorName} ${notifText(rec.type)}`,
      url: SITE_URL + deepLink(rec.type, rec.post_id ?? null, rec.actor_id ?? null),
      tag: rec.type
    });

    let sent = 0;
    for (const s of subs) {
      try {
        await webpush.sendNotification(
          { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
          payload
        );
        sent++;
      } catch (err) {
        const code = (err as { statusCode?: number }).statusCode;
        if (code === 404 || code === 410) {
          await admin.from("push_subscriptions").delete().eq("endpoint", s.endpoint);
        }
      }
    }
    return new Response(`push: ${sent}/${subs.length}`, { status: 200 });
  } catch (e) {
    return new Response("error: " + (e as Error).message, { status: 500 });
  }
});
