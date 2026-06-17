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
  try{
    if(!window.JP) return;
    if(!JP.user || !JP.user()){ if(JP.loadMe) await JP.loadMe(); }
    if(!JP.user || !JP.user()) return;   // pas connecté
    // (Aucun lien d'administration n'est révélé dans le menu : l'accès se fait
    //  uniquement via l'URL privée, connue de l'admin.)
    let count = await JP.unreadCount();
    paint(count);
    // Temps réel : à chaque nouvelle notif, on ré-interroge le compteur
    if(JP.subscribeNotifications){
      JP.subscribeNotifications(async()=>{
        count = await JP.unreadCount();
        paint(count);
      });
    }
  }catch(e){ /* silencieux */ }
})();
