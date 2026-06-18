/* ============================================================
   Jurapotes — Installation de l'app (PWA)
   API : window.JPInstall.{state, promptInstall, isStandalone}
   - Android/desktop Chrome : installation native en 1 clic (beforeinstallprompt)
   - iOS : pas d'API d'installation -> on renvoie 'ios' (instructions à montrer),
     'ios-bad-browser' si on n'est pas dans Safari (installation impossible ailleurs).
   ============================================================ */
window.JPInstall = (function () {
  let deferred = null;
  window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferred = e;
    document.dispatchEvent(new Event('jp-install-available'));
  });
  window.addEventListener('appinstalled', () => {
    deferred = null;
    document.dispatchEvent(new Event('jp-installed'));
  });

  function isStandalone() {
    return window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true;
  }
  const ua = navigator.userAgent || '';
  function isIOS() { return /iphone|ipad|ipod/i.test(ua) && !window.MSStream; }
  function isIOSSafari() {
    // Safari iOS : pas de CriOS (Chrome), FxiOS (Firefox), EdgiOS, ni navigateur intégré (FBAN/Instagram…)
    return isIOS() && /safari/i.test(ua) && !/crios|fxios|edgios|fban|fbav|instagram|line|gsa/i.test(ua);
  }

  function state() {
    if (isStandalone()) return 'installed';
    if (deferred) return 'prompt';
    if (isIOS()) return isIOSSafari() ? 'ios' : 'ios-bad-browser';
    return 'unknown';
  }
  async function promptInstall() {
    if (!deferred) return { ok: false };
    deferred.prompt();
    let outcome = 'dismissed';
    try { outcome = (await deferred.userChoice).outcome; } catch (e) {}
    deferred = null;
    return { ok: outcome === 'accepted' };
  }
  return { state, promptInstall, isStandalone, isIOS, isIOSSafari };
})();
