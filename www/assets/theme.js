/* ============================================================
   Jurapotes — Mode sombre 🌙
   À charger TÔT (dans <head>, après le <link> du CSS) pour
   appliquer le thème avant le rendu (pas de flash).
   - Préférence mémorisée dans localStorage ('jp-theme').
   - À défaut : suit la préférence système.
   Expose window.JPTheme {get, set, toggle}.
   ============================================================ */
(function () {
  function systemDark() {
    return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  }
  function stored() {
    try { return localStorage.getItem('jp-theme'); } catch (e) { return null; }
  }
  function apply(mode) {
    if (mode === 'dark') document.documentElement.setAttribute('data-theme', 'dark');
    else document.documentElement.removeAttribute('data-theme');
  }
  // Application immédiate (avant le rendu du body)
  var pref = stored();
  apply(pref ? pref : (systemDark() ? 'dark' : 'light'));

  window.JPTheme = {
    get: function () {
      return document.documentElement.getAttribute('data-theme') === 'dark' ? 'dark' : 'light';
    },
    set: function (mode) {
      apply(mode);
      try { localStorage.setItem('jp-theme', mode); } catch (e) {}
      document.dispatchEvent(new CustomEvent('jp-theme-change', { detail: this.get() }));
    },
    toggle: function () {
      this.set(this.get() === 'dark' ? 'light' : 'dark');
      return this.get();
    }
  };
})();
