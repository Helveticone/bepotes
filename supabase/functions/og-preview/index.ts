// ============================================================
//  JURAPOTES — Edge Function « og-preview »
//  Récupère les métadonnées Open Graph d'une URL (titre, desc,
//  image, site) côté serveur (contourne le CORS du navigateur).
//  Appelée par le front à la publication : sb.functions.invoke('og-preview', { body:{ url } })
//  ------------------------------------------------------------
//  Déploiement :  supabase functions deploy og-preview
//  (voir supabase/apercu-liens-GUIDE.md)
// ============================================================
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function json(obj: unknown, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}
function decode(s: string): string {
  return (s || "")
    .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"').replace(/&#0?39;/g, "'").replace(/&#x27;/gi, "'")
    .replace(/&nbsp;/g, " ").trim();
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const { url } = await req.json();
    if (!url || !/^https?:\/\//i.test(url)) return json({});

    const res = await fetch(url, {
      headers: { "User-Agent": "Mozilla/5.0 (compatible; JurapotesBot/1.0; +https://jurapotes-betatest.pages.dev)" },
      redirect: "follow",
    });
    const ct = res.headers.get("content-type") || "";
    if (!ct.includes("text/html")) return json({});
    const head = (await res.text()).slice(0, 250000);

    const meta = (prop: string): string => {
      // <meta property="og:title" content="..."> ou name=... (ordre des attributs indifférent)
      const a = new RegExp(`<meta[^>]+(?:property|name)=["']${prop}["'][^>]*content=["']([^"']*)["']`, "i");
      const b = new RegExp(`<meta[^>]+content=["']([^"']*)["'][^>]*(?:property|name)=["']${prop}["']`, "i");
      const m = head.match(a) || head.match(b);
      return m ? decode(m[1]) : "";
    };

    let title = meta("og:title") || decode((head.match(/<title[^>]*>([^<]*)<\/title>/i)?.[1] || ""));
    const description = meta("og:description") || meta("description");
    let image = meta("og:image") || meta("og:image:url") || meta("twitter:image");
    const site = meta("og:site_name");
    if (image && !/^https?:\/\//i.test(image)) { try { image = new URL(image, url).href; } catch (_e) {} }

    return json({ title, description, image, site });
  } catch (_e) {
    return json({});
  }
});
