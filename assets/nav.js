/* ============================================================
   Jurapotes — Menu mobile (tiroir latéral gauche, façon Facebook)
   - Bouton ☰ dans la barre du haut
   - Onglet « Menu » (☰) ajouté dans la barre du bas (toujours visible)
   Les deux ouvrent un tiroir gauche avec TOUTES les sections.
   Centralise la nav mobile (un seul endroit à maintenir).
   À inclure (après app.supabase.js) sur les pages connectées.
   ============================================================ */
(function () {
  function init() {
    const navLinks = document.querySelector('nav .nav-links');
    if (!navLinks || document.querySelector('.drawer-bg')) return;

    const I = {
      fil: '<path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
      amis: '<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/>',
      groupes: '<path d="M17 21v-2a4 4 0 0 0-3-3.87M9 21v-2a4 4 0 0 1 3-3.87"/><circle cx="9" cy="7" r="3"/><circle cx="17" cy="9" r="3"/>',
      pages: '<path d="M3 9l1-5h16l1 5M4 9v10a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1V9"/>',
      marche: '<path d="M3 9l1-5h16l1 5M4 9v10a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1V9M9 13h6"/>',
      events: '<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>',
      messages: '<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>',
      notif: '<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/>',
      profil: '<circle cx="12" cy="8" r="4"/><path d="M4 21v-1a6 6 0 0 1 12 0v1"/>',
      search: '<circle cx="11" cy="11" r="8"/><path d="M21 21l-4.3-4.3"/>',
      burger: '<path d="M3 6h18M3 12h18M3 18h18"/>'
    };
    const link = (href, label, path) =>
      `<a href="${href}"><svg viewBox="0 0 24 24">${path}</svg><span>${label}</span></a>`;

    // --- Tiroir gauche ---
    const bg = document.createElement('div');
    bg.className = 'drawer-bg';
    bg.innerHTML =
      '<aside class="drawer" role="dialog" aria-label="Menu">' +
        '<div class="drawer-head"><span class="wordmark">jura<span class="wm-red">potes</span></span>' +
        '<button class="drawer-x" type="button" aria-label="Fermer">&times;</button></div>' +
        '<nav class="drawer-links">' +
          link('fil.html', 'Le fil', I.fil) +
          link('recherche.html', 'Recherche', I.search) +
          link('amis.html', 'Amis', I.amis) +
          link('groupes.html', 'Groupes', I.groupes) +
          link('pages.html', 'Pages', I.pages) +
          link('marketplace.html', 'Marché', I.marche) +
          link('evenements.html', 'Événements', I.events) +
          link('messages.html', 'Messages', I.messages) +
          link('notifications.html', 'Notifications', I.notif) +
          link('profil.html', 'Profil', I.profil) +
          '<a href="#" class="drawer-logout" id="drawerLogout">Déconnexion</a>' +
        '</nav>' +
      '</aside>';
    document.body.appendChild(bg);

    const here = (location.pathname.split('/').pop() || 'index.html');
    bg.querySelectorAll('.drawer-links a').forEach(a => {
      if (a.getAttribute('href') === here) a.classList.add('active');
    });

    const open = () => bg.classList.add('open');
    const close = () => bg.classList.remove('open');
    bg.addEventListener('click', e => { if (e.target === bg) close(); });
    bg.querySelector('.drawer-x').addEventListener('click', close);
    bg.querySelector('#drawerLogout').addEventListener('click', e => { e.preventDefault(); if (window.JP && JP.logout) JP.logout(); });

    // --- Bouton ☰ dans la barre du haut ---
    const burger = document.createElement('button');
    burger.className = 'nav-burger';
    burger.type = 'button';
    burger.setAttribute('aria-label', 'Menu');
    burger.innerHTML = `<svg viewBox="0 0 24 24">${I.burger}</svg>`;
    burger.addEventListener('click', open);
    navLinks.insertBefore(burger, navLinks.firstChild);

    // --- Onglet « Menu » dans la barre du bas (toujours visible en mobile) ---
    const mob = document.querySelector('.mobile-nav');
    if (mob && !mob.querySelector('.mn-menu')) {
      const m = document.createElement('a');
      m.href = '#'; m.className = 'mn-menu';
      m.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="${'M3 6h18M3 12h18M3 18h18'}"/></svg><span>Menu</span>`;
      m.addEventListener('click', e => { e.preventDefault(); open(); });
      mob.appendChild(m);
    }
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
