/* PWA temporairement désactivée.
   Ce script DÉSINSTALLE tout service worker existant et vide les caches,
   pour réparer les téléphones bloqués sur une page blanche. */
(function () {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then((regs) => {
      regs.forEach((r) => r.unregister());
    }).catch(() => {});
  }
  if (window.caches && caches.keys) {
    caches.keys().then((keys) => keys.forEach((k) => caches.delete(k))).catch(() => {});
  }
})();
