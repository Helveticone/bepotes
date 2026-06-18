/* ============================================================
   Jurapotes — Service Worker PUSH (notifications)
   N'intercepte AUCUNE requête réseau (pas de cache) -> impossible
   de provoquer un écran blanc / contenu périmé. Il ne fait que
   recevoir les push et ouvrir la bonne page au clic.
   ============================================================ */
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

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