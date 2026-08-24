/* ============================================================
   Jurapotes — Service Worker : PUSH UNIQUEMENT
   ------------------------------------------------------------
   IMPORTANT : aucun handler `fetch`.
   -> Les navigations (changements de page) NE passent PLUS par le SW,
      donc le navigateur n'a plus à réveiller le SW à chaque page
      (sur mobile, ce réveil ajoutait plusieurs secondes par navigation).
   -> Le cache des assets est déjà assuré par le cache HTTP (immutable 1 an
      via _headers + ?v=N), donc le cache SW était redondant : on le supprime.
   Le SW ne sert plus qu'aux notifications push.
   ============================================================ */

self.addEventListener('install', () => { self.skipWaiting(); });

self.addEventListener('activate', (e) => {
  e.waitUntil((async () => {
    // Purge les anciens caches SW (plus utilisés) pour libérer de l'espace.
    try {
      const keys = await caches.keys();
      await Promise.all(keys.filter(k => k.startsWith('jp-')).map(k => caches.delete(k)));
    } catch (_) {}
    await self.clients.claim();
  })());
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
