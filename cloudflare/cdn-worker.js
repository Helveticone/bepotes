/* ============================================================
   BePotes — CDN média (Cloudflare devant Supabase Storage)
   ------------------------------------------------------------
   Met en cache, au bord du réseau Cloudflare, les fichiers PUBLICS
   du Storage Supabase. Les vues répétées sont servies par Cloudflare
   (egress gratuit) → la bande passante facturée par Supabase chute.

   Déploiement : voir cloudflare/CDN-GUIDE.md.
   Route à associer : cdn.bepotes.be/*
   ============================================================ */

// 🔧 Mets ici l'URL de TON projet Supabase (sans slash final) :
const SUPABASE_ORIGIN = 'https://nvlquqrsjmwgtkhmxazq.supabase.co';

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // On ne sert que des lectures de fichiers publics (sécurité).
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('Méthode non autorisée', { status: 405 });
    }
    if (!url.pathname.startsWith('/storage/v1/object/public/')) {
      return new Response('Introuvable', { status: 404 });
    }

    const cache = caches.default;
    const hit = await cache.match(request);
    if (hit) return hit;

    const originUrl = SUPABASE_ORIGIN + url.pathname + url.search;
    let res = await fetch(originUrl, { cf: { cacheEverything: true, cacheTtl: 31536000 } });

    // On réécrit les en-têtes pour une mise en cache longue + CORS ouverte.
    res = new Response(res.body, res);
    res.headers.set('Cache-Control', 'public, max-age=31536000, immutable');
    res.headers.set('Access-Control-Allow-Origin', '*');
    res.headers.set('X-BePotes-CDN', '1');

    if (res.ok) ctx.waitUntil(cache.put(request, res.clone()));
    return res;
  }
};

