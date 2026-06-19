/* ============================================================
   Jurapotes — Stories éphémères (24 h)
   window.JPStories.mount(el) : rend la barre de stories dans `el`
   + gère la création et la visionneuse plein écran.
   Nécessite JP (app.supabase.js) chargé et l'utilisateur connecté.
   ============================================================ */
window.JPStories = (function () {
  let el = null, groups = [], fileInput = null;
  let viewer = null, gi = 0, ii = 0, timer = null;

  async function mount(container) {
    el = container; if (!el) return;
    ensureFileInput();
    await render();
  }

  async function render() {
    groups = await JP.listStories();
    const me = JP.user();
    const addAvatar = me && me.avatar ? `<img src="${me.avatar}" alt="">` : '+';
    let html = `<div class="story-item story-add"><div class="story-ring"><div class="si-inner">${addAvatar}<span class="si-badge">+</span></div></div><div class="story-name">Ta story</div></div>`;
    html += groups.map((g, idx) => {
      const inner = g.avatar ? `<img src="${g.avatar}" alt="">` : JP.esc((g.name || '?').slice(0, 1).toUpperCase());
      return `<div class="story-item" data-gi="${idx}"><div class="story-ring ${g.hasUnseen ? '' : 'seen'}"><div class="si-inner">${inner}</div></div><div class="story-name">${g.mine ? 'Toi' : JP.esc(g.name)}</div></div>`;
    }).join('');
    el.innerHTML = html;
    el.querySelector('.story-add').addEventListener('click', () => fileInput.click());
    el.querySelectorAll('[data-gi]').forEach(node => node.addEventListener('click', () => open(+node.dataset.gi, 0)));
  }

  function ensureFileInput() {
    if (fileInput) return;
    fileInput = document.createElement('input');
    fileInput.type = 'file'; fileInput.accept = 'image/*,video/*'; fileInput.style.display = 'none';
    document.body.appendChild(fileInput);
    fileInput.addEventListener('change', async () => {
      const f = fileInput.files[0]; fileInput.value = '';
      if (!f) return;
      if (f.type.startsWith('video/') && f.size > 300 * 1024 * 1024) { JP.toast('Vidéo trop lourde (300 Mo max)'); return; }
      const text = (prompt('Légende (optionnel) :', '') || '').trim();
      JP.toast('Publication de la story…');
      const r = await JP.addStory({ file: f, text });
      if (r.ok) { JP.toast('Story publiée ! 🎉'); await render(); }
      else JP.toast(r.msg || 'Échec');
    });
  }

  function ensureViewer() {
    if (viewer) return;
    viewer = document.createElement('div');
    viewer.className = 'story-viewer';
    viewer.innerHTML = '<div class="sv-bars"></div><div class="sv-head"></div><div class="sv-stage"></div><div class="sv-cap"></div><div class="sv-nav prev"></div><div class="sv-nav next"></div>';
    document.body.appendChild(viewer);
    viewer.querySelector('.sv-nav.prev').addEventListener('click', prev);
    viewer.querySelector('.sv-nav.next').addEventListener('click', next);
    document.addEventListener('keydown', (e) => {
      if (!viewer.classList.contains('open')) return;
      if (e.key === 'Escape') close();
      else if (e.key === 'ArrowRight') next();
      else if (e.key === 'ArrowLeft') prev();
    });
  }

  function open(g, i) { ensureViewer(); gi = g; ii = i; viewer.classList.add('open'); document.body.style.overflow = 'hidden'; showItem(); }
  function stop() { if (timer) { clearTimeout(timer); timer = null; } const v = viewer && viewer.querySelector('.sv-stage video'); if (v) { try { v.pause(); } catch (e) {} } }
  function close() { stop(); if (viewer) viewer.classList.remove('open'); document.body.style.overflow = ''; render(); }
  function next() { const g = groups[gi]; if (!g) return close(); if (ii < g.items.length - 1) { ii++; showItem(); } else if (gi < groups.length - 1) { gi++; ii = 0; showItem(); } else close(); }
  function prev() { if (ii > 0) { ii--; showItem(); } else if (gi > 0) { gi--; ii = 0; showItem(); } else showItem(); }

  function animateBar(barEl, ms) {
    if (!barEl) return;
    barEl.style.transition = 'none'; barEl.style.width = '0%';
    void barEl.offsetWidth;
    barEl.style.transition = 'width ' + ms + 'ms linear'; barEl.style.width = '100%';
  }

  function showItem() {
    stop();
    const g = groups[gi]; if (!g) return close();
    const it = g.items[ii]; if (!it) return close();

    const head = viewer.querySelector('.sv-head');
    head.innerHTML = JP.avatarHTML(g.name, g.avatar, 'av')
      + `<div><b>${g.mine ? 'Toi' : JP.esc(g.name)}</b><div class="sv-time">${JP.timeAgo(it.ts)}</div></div>`
      + `<div class="sv-actions">${g.mine ? '<button class="sv-del" type="button" title="Supprimer">🗑</button>' : ''}<button class="sv-close" type="button" aria-label="Fermer">&times;</button></div>`;
    head.querySelector('.sv-close').addEventListener('click', close);
    const del = head.querySelector('.sv-del');
    if (del) del.addEventListener('click', async () => { if (confirm('Supprimer cette story ?')) { await JP.deleteStory(it.id); close(); } });

    const bars = viewer.querySelector('.sv-bars');
    bars.innerHTML = g.items.map((x, k) => `<div class="sv-bar"><i style="width:${k < ii ? 100 : 0}%"></i></div>`).join('');
    const bar = bars.children[ii] ? bars.children[ii].querySelector('i') : null;

    const cap = viewer.querySelector('.sv-cap');
    cap.textContent = it.text || ''; cap.style.display = it.text ? '' : 'none';

    const stage = viewer.querySelector('.sv-stage'); stage.innerHTML = '';
    if (it.type === 'video') {
      const v = document.createElement('video');
      v.src = it.url; v.className = 'sv-media'; v.autoplay = true; v.playsInline = true; v.setAttribute('playsinline', '');
      stage.appendChild(v);
      v.addEventListener('loadedmetadata', () => animateBar(bar, (v.duration && isFinite(v.duration) ? v.duration * 1000 : 6000)));
      v.addEventListener('ended', next);
      v.play().catch(() => {});
    } else {
      const img = document.createElement('img'); img.src = it.url; img.className = 'sv-media'; stage.appendChild(img);
      animateBar(bar, 5000);
      timer = setTimeout(next, 5000);
    }
    if (JP.user()) JP.markStoryViewed(it.id);
  }

  return { mount };
})();
