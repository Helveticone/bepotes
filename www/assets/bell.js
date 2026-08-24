/* Cloche de notifications : compteur initial + mise à jour temps réel.
   À inclure après app.supabase.js sur les pages connectées. */
(async function(){
  // Marquer l'onglet actif dans la barre mobile
  try{
    var here=(location.pathname.split('/').pop()||'fil.html');
    document.querySelectorAll('.mobile-nav a').forEach(function(a){
      if(a.getAttribute('href')===here) a.classList.add('active');
    });
  }catch(e){}
  function paint(c){
    const b=document.getElementById('bellCount');
    if(b){
      if(c>0){ b.textContent=c>99?'99+':c; b.classList.add('show'); }
      else { b.classList.remove('show'); }
    }
    // Badge de la barre mobile
    const mb=document.getElementById('mnBell');
    if(mb){
      if(c>0){ mb.textContent=c>9?'9+':c; mb.classList.add('show'); }
      else { mb.classList.remove('show'); }
    }
  }
  /* Badge « messages non lus » sur le lien Messages (haut + barre mobile) */
  function paintMsg(c){
    document.querySelectorAll('nav .nav-links a[href="messages.html"], .mobile-nav a[href="messages.html"]').forEach(function(a){
      let b=a.querySelector('.msg-badge');
      if(c>0){ if(!b){ b=document.createElement('span'); b.className='msg-badge'; a.appendChild(b); } b.textContent=c>9?'9+':c; }
      else if(b){ b.remove(); }
    });
  }
  async function refreshMsg(){ try{ const u=await JP.unreadCounts(); paintMsg(u.total||0); }catch(e){} }

  try{
    if(!window.JP) return;
    if(!JP.user || !JP.user()){ if(JP.loadMe) await JP.loadMe(); }
    if(!JP.user || !JP.user()) return;   // pas connecté
    let count = await JP.unreadCount();
    paint(count);
    if(JP.unreadCounts){ refreshMsg(); document.addEventListener('jp-msg-read', refreshMsg); }
    // Temps réel : à chaque nouvelle notif, on ré-interroge les compteurs
    if(JP.subscribeNotifications){
      JP.subscribeNotifications(async()=>{
        count = await JP.unreadCount();
        paint(count);
        refreshMsg();
      });
    }
  }catch(e){ /* silencieux */ }
})();

