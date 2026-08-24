/* ============================================================
   BePotes — Menu mobile (tiroir latéral gauche, façon Facebook)
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

    // Connecté (nav.js n'est chargé que sur les pages connectées) : le logo ramène au fil,
    // pas à la page d'accueil publique (évite l'impression d'être déconnecté).
    const navLogo = document.querySelector('nav .logo');
    if (navLogo) navLogo.setAttribute('href', 'fil.html');

    const I = {
      fil: '<path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
      amis: '<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/>',
      groupes: '<path d="M17 21v-2a4 4 0 0 0-3-3.87M9 21v-2a4 4 0 0 1 3-3.87"/><circle cx="9" cy="7" r="3"/><circle cx="17" cy="9" r="3"/>',
      pages: '<path d="M3 9l1-5h16l1 5M4 9v10a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1V9"/>',
      marche: '<path d="M3 9l1-5h16l1 5M4 9v10a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1V9M9 13h6"/>',
      events: '<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>',
      messages: '<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>',
      reels: '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 8h18M8 3v5M10 12l5 3-5 3z"/>',
      trophy: '<path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0z"/><path d="M7 6H4v2a3 3 0 0 0 3 3M17 6h3v2a3 3 0 0 1-3 3"/>',
      notif: '<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/>',
      profil: '<circle cx="12" cy="8" r="4"/><path d="M4 21v-1a6 6 0 0 1 12 0v1"/>',
      search: '<circle cx="11" cy="11" r="8"/><path d="M21 21l-4.3-4.3"/>',
      params: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.6 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.6a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>',
      burger: '<path d="M3 6h18M3 12h18M3 18h18"/>',
      faq: '<circle cx="12" cy="12" r="10"/><path d="M9.1 9a3 3 0 0 1 5.8 1c0 2-3 2.3-3 4"/><path d="M12 17h.01"/>',
      pub: '<path d="M3 11l15-5v13L3 15z"/><path d="M11.5 16a3 3 0 0 1-5-2"/>',
      moon: '<path d="M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z"/>',
      sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>'
    };
    const link = (href, label, path) =>
      `<a href="${href}"><svg viewBox="0 0 24 24">${path}</svg><span>${label}</span></a>`;

    // --- Tiroir gauche ---
    const bg = document.createElement('div');
    bg.className = 'drawer-bg';
    bg.innerHTML =
      '<aside class="drawer" role="dialog" aria-label="Menu">' +
        '<div class="drawer-head"><span class="wordmark">be<span class="wm-red">potes</span></span>' +
        '<button class="drawer-x" type="button" aria-label="Fermer">&times;</button></div>' +
        '<nav class="drawer-links">' +
          link('fil.html', 'Le fil', I.fil) +
          link('reels.html', 'Reels', I.reels) +
          link('classement.html', 'Classement', I.trophy) +
          link('recherche.html', 'Recherche', I.search) +
          link('amis.html', 'Amis', I.amis) +
          link('groupes.html', 'Groupes', I.groupes) +
          link('pages.html', 'Pages', I.pages) +
          link('marketplace.html', 'Marché', I.marche) +
          link('evenements.html', 'Événements', I.events) +
          link('messages.html', 'Messages', I.messages) +
          link('notifications.html', 'Notifications', I.notif) +
          link('profil.html', 'Profil', I.profil) +
          link('parametres.html', 'Paramètres', I.params) +
          link('faq.html', 'FAQ / Aide', I.faq) +
          link('publicite.html', 'Publicité', I.pub) +
          '<button type="button" class="drawer-theme" id="drawerTheme"><svg viewBox="0 0 24 24"></svg><span></span></button>' +
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

    // --- Bascule de thème (clair / sombre) ---
    const navTheme = document.createElement('button');
    navTheme.className = 'nav-theme';
    navTheme.type = 'button';
    navTheme.setAttribute('aria-label', 'Changer de thème');
    navLinks.insertBefore(navTheme, burger.nextSibling);
    const drawerTheme = bg.querySelector('#drawerTheme');
    function paintTheme() {
      const dark = window.JPTheme && JPTheme.get() === 'dark';
      const icon = dark ? I.sun : I.moon;
      const label = dark ? 'Mode clair' : 'Mode sombre';
      navTheme.innerHTML = `<svg viewBox="0 0 24 24">${icon}</svg>`;
      navTheme.title = label;
      if (drawerTheme) {
        drawerTheme.querySelector('svg').innerHTML = icon;
        drawerTheme.querySelector('span').textContent = label;
      }
    }
    function toggleTheme() { if (window.JPTheme) { JPTheme.toggle(); paintTheme(); } }
    navTheme.addEventListener('click', toggleTheme);
    if (drawerTheme) drawerTheme.addEventListener('click', toggleTheme);
    document.addEventListener('jp-theme-change', paintTheme);
    paintTheme();

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

