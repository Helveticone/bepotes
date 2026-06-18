/* ============================================================
   Jurapotes — PWA / Service Worker
   - Enregistre le SW push (sw-push.js) : il ne met RIEN en cache,
     donc aucun risque d'écran blanc / contenu périmé.
   - Nettoie une fois les anciens caches (bug historique).
   ============================================================ */
(function () {
  if (!('serviceWorker' in navigator)) return;
  // Purge des anciens caches éventuels (ancienne PWA)
  if (window.caches && caches.keys) {
    caches.keys().then((ks) => ks.forEach((k) => caches.delete(k))).catch(() => {});
  }
  // Enregistre le SW push (reçoit les notifications même app fermée)
  navigator.serviceWorker.register('/sw-push.js').catch(() => {});
})();
