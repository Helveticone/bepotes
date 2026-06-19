/* ============================================================
   Jurapotes — Service Worker : PUSH + cache des ASSETS (sûr)
   ------------------------------------------------------------
   Stratégie volontairement prudente :
   - /assets/* (CSS/JS) + polices + CDN libs = VERSIONNÉS -> cache-first.
     (une nouvelle version = nouvelle URL ?v=N => jamais de périmé.)
   - Navigations (HTML) = RÉSEAU d'abord ; repli /offline.html hors-ligne.
     (on ne met JAMAIS le HTML en cache -> pas de page périmée.)
   - Supabase (API/Storage) et tout le reste = réseau direct, pas de cache SW.
   ============================================================ */
const CACHE = 'jp-assets-v1';
const OFFLINE = '/offline.html';

self.addEventListener('install', (e) => {
  e.waitUntil((async () => {
    try { const c = await caches.open(CACHE); await c.add(OFFLINE); } catch (_) {}
    self.skipWaiting();
  })());
});

self.addEventListener('activate', (e) => {
  e.waitUntil((async () => {
    try {
      const keys = await caches.keys();
      await Promise.all(keys.filter(k => k.startsWith('jp-') && k !== CACHE).map(k => caches.delete(k)));
    } catch (_) {}
    await self.clients.claim();
  })());
});

function isCacheableAsset(url) {
  return (url.origin === self.location.origin && url.pathname.startsWith('/assets/'))
    || url.hostname.includes('fonts.googleapis.com')
    || url.hostname.includes('fonts.gstatic.com')
    || url.hostname.includes('cdn.jsdelivr.net');
}

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;            // jamais d'écriture en cache
  let url;
  try { url = new URL(req.url); } catch (_) { return; }

  // 1) Assets versionnés -> cache-first (instantané au retour)
  if (isCacheableAsset(url)) {
    e.respondWith((async () => {
      try {
        const cache = await caches.open(CACHE);
        const hit = await cache.match(req);
        if (hit) return hit;
        const res = await fetch(req);
        if (res && (res.ok || res.type === 'opaque')) cache.put(req, res.clone());
        return res;
      } catch (_) { return fetch(req); }
    })());
    return;
  }

  // 2) Navigations -> réseau d'abord, repli hors-ligne (jamais de HTML en cache)
  if (req.mode === 'navigate') {
    e.respondWith((async () => {
      try { return await fetch(req); }
      catch (_) { return (await caches.match(OFFLINE)) || Response.error(); }
    })());
    return;
  }

  // 3) Le reste (Supabase, etc.) : réseau direct (pas de respondWith)
});

self.addEventListener('push', (e) => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (_) { d = { body: e.data && e.data.text() }; }
  const title = d.title || 'Jurapotes';
  const opts = {
    body: d.body || '',
    icon: '/icons/apple-touch-icon.png',
    badge: '/icons/apple-touch-icon.png',
    data: { url: d.url || '/fil.html' },
    tag: d.tag || undefined
  };
  e.waitUntil(self.registration.showNotification(title, opts));
});

self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  const url = (e.notification.data && e.notification.data.url) || '/fil.html';
  e.waitUntil((async () => {
    const all = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const c of all) {
      if ('focus' in c) { try { await c.navigate(url); } catch (_) {} return c.focus(); }
    }
    if (self.clients.openWindow) return self.clients.openWindow(url);
  })());
});
