/* ============================================================
   Jurapotes — Notifications push (côté client)
   API : window.JPPush.{supported, status, enable, disable}
   Nécessite : JP (app.supabase.js) chargé, VAPID_PUBLIC dans config.js,
   et le SW sw-push.js (enregistré par pwa.js).
   ============================================================ */
window.JPPush = (function () {
  const VAPID = (window.JP_CONFIG && window.JP_CONFIG.VAPID_PUBLIC) || '';

  function supported() {
    return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
  }
  function urlB64ToUint8(base64) {
    const pad = '='.repeat((4 - (base64.length % 4)) % 4);
    const b = (base64 + pad).replace(/-/g, '+').replace(/_/g, '/');
    const raw = atob(b);
    return Uint8Array.from([...raw].map((c) => c.charCodeAt(0)));
  }
  async function currentSub() {
    if (!supported()) return null;
    const reg = await navigator.serviceWorker.ready;
    return reg.pushManager.getSubscription();
  }
  async function status() {
    if (!supported()) return 'unsupported';
    if (Notification.permission === 'denied') return 'denied';
    const s = await currentSub();
    return s ? 'on' : 'off';
  }
  async function enable() {
    if (!supported()) return { ok: false, msg: "Non supporté sur cet appareil/navigateur" };
    if (!VAPID) return { ok: false, msg: "Clé VAPID manquante (assets/config.js)" };
    const perm = await Notification.requestPermission();
    if (perm !== 'granted') return { ok: false, msg: "Permission refusée" };
    const reg = await navigator.serviceWorker.ready;
    let sub = await reg.pushManager.getSubscription();
    if (!sub) {
      sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlB64ToUint8(VAPID)
      });
    }
    const j = sub.toJSON();
    if (!window.JP || !JP.savePushSubscription) return { ok: false, msg: "JP non chargé" };
    return JP.savePushSubscription({ endpoint: sub.endpoint, p256dh: j.keys.p256dh, auth: j.keys.auth });
  }
  async function disable() {
    const s = await currentSub();
    if (!s) return { ok: true };
    try { if (window.JP && JP.deletePushSubscription) await JP.deletePushSubscription(s.endpoint); } catch (e) {}
    try { await s.unsubscribe(); } catch (e) {}
    return { ok: true };
  }
  return { supported, status, enable, disable };
})();
