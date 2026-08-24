/* ============================================================
   BePotes — PWA / Service Worker
   - Désinstalle l'ANCIEN sw.js (il faisait clients.navigate -> rechargements
     en boucle / logo qui « disparaît »).
   - Enregistre le SW push (sw-push.js) : il ne met RIEN en cache.
   - Purge une fois les anciens caches.
   ============================================================ */
(function () {
  if (!('serviceWorker' in navigator)) return;
  // Purge les anciens caches (legacy sw.js) mais GARDE le cache d'assets actuel (jp-*)
  if (window.caches && caches.keys) {
    caches.keys().then((ks) => ks.forEach((k) => { if (!k.startsWith('jp-')) caches.delete(k); })).catch(() => {});
  }
  navigator.serviceWorker.getRegistrations().then((regs) => {
    regs.forEach((r) => {
      const url = (r.active && r.active.scriptURL) || (r.installing && r.installing.scriptURL) || '';
      if (url.endsWith('/sw.js')) r.unregister();   // ancien SW « reloader » -> on l'enlève
    });
  }).catch(() => {});
  navigator.serviceWorker.register('/sw-push.js').catch(() => {});
})();

