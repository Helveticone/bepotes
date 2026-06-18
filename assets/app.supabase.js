/* ============================================================
   Jurapotes — moteur Supabase (réseau partagé entre membres)
   ------------------------------------------------------------
   Remplace l'ancien app.js (localStorage).
   Nécessite, AVANT ce script, dans chaque page :
     <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
     <script src="assets/config.js"></script>
   Les méthodes qui touchent le réseau sont ASYNC (utiliser await).
   ============================================================ */

window.JP = (() => {

  const cfg = window.JP_CONFIG || {};
  if(!window.supabase || !window.supabase.createClient){
    console.error('Supabase non chargé');
  }
  const sb = window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON);

  /* ---------- Helpers visuels (inchangés) ---------- */
  const COLORS = ['#E11D2A','#F2723B','#1A1416','#B01521','#C44536','#7A2E2E','#D6603A','#9C3848'];
  function colorFor(name){ let h=0; for(const c of (name||'?')) h=(h*31+c.charCodeAt(0))>>>0; return COLORS[h%COLORS.length]; }
  const initials = n => (n||'?').trim().split(/\s+/).map(w=>w[0]).slice(0,2).join('').toUpperCase();
  const esc = s => (s||'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

  function timeAgo(ts){
    const t = typeof ts==='number' ? ts : new Date(ts).getTime();
    const s=Math.floor((Date.now()-t)/1000);
    if(s<60) return "à l'instant";
    if(s<3600) return Math.floor(s/60)+' min';
    if(s<86400) return Math.floor(s/3600)+' h';
    if(s<604800) return Math.floor(s/86400)+' j';
    return new Date(t).toLocaleDateString('fr-CH',{day:'numeric',month:'short'});
  }

  function avatarHTML(name, avatar, cls='av', style=''){
    if(avatar) return `<div class="${cls} avatar" style="${style}"><img src="${avatar}" alt=""></div>`;
    return `<div class="${cls}" style="background:${colorFor(name)};${style}">${initials(name)}</div>`;
  }

  /* ---------- @mentions ----------
     Stockage : @[Nom](uuid). Affichage : lien vers le profil. */
  function mentionHTML(text){
    return esc(text).replace(/@\[([^\]]+)\]\(([0-9a-fA-F-]{36})\)/g,
      (m,name,id)=>`<a class="mention" href="membre.html?id=${id}">@${name}</a>`);
  }
  // Convertit les "@Nom" choisis dans l'autocomplétion en jetons @[Nom](uuid)
  function tokenizeMentions(text, mentions){
    let out=text||'';
    (mentions||[]).forEach(m=>{
      const needle='@'+m.name;
      const idx=out.indexOf(needle);
      if(idx>=0) out = out.slice(0,idx) + '@['+m.name+']('+m.id+')' + out.slice(idx+needle.length);
    });
    return out;
  }
  // Autocomplétion : attache à un <textarea>/<input>. Mémorise el._mentions.
  function attachMentions(el){
    if(!el || el._mentionsAttached) return;
    el._mentionsAttached=true; el._mentions=[];
    let box=null, items=[], active=-1;
    function close(){ if(box){ box.remove(); box=null; } items=[]; active=-1; }
    function currentQuery(){
      const pos=el.selectionStart, before=el.value.slice(0,pos);
      const m=before.match(/(?:^|\s)@([\p{L}][\p{L}\-' ]{0,28})$/u);
      if(!m) return null;
      return { q:m[1].trim(), start:pos-m[1].length-1, end:pos };
    }
    async function update(){
      const cq=currentQuery();
      if(!cq || cq.q.length<1){ close(); return; }
      let list=[]; try{ list=await members(cq.q); }catch(e){ list=[]; }
      if(!list.length){ close(); return; }
      items=list.slice(0,6); active=0; render(cq);
    }
    function render(cq){
      if(!box){ box=document.createElement('div'); box.className='mention-pop'; document.body.appendChild(box); }
      box.innerHTML=items.map((m,i)=>`<button type="button" class="mi ${i===active?'on':''}" data-i="${i}">${avatarHTML(m.name,m.avatar,'av')}<span>${esc(m.name)}</span></button>`).join('');
      const r=el.getBoundingClientRect();
      box.style.left=(r.left+window.scrollX)+'px';
      box.style.top=(r.bottom+window.scrollY+4)+'px';
      box.style.width=Math.min(Math.max(r.width,200),320)+'px';
      box.querySelectorAll('.mi').forEach(b=>b.addEventListener('mousedown',e=>{ e.preventDefault(); pick(+b.dataset.i, cq); }));
    }
    function pick(i, cq){
      const m=items[i]; if(!m) return;
      const before=el.value.slice(0,cq.start), after=el.value.slice(cq.end);
      el.value = before + '@' + m.name + ' ' + after;
      el._mentions.push({name:m.name, id:m.id});
      const np=(before+'@'+m.name+' ').length;
      try{ el.setSelectionRange(np,np); }catch(_){}
      el.focus(); close();
    }
    el.addEventListener('input', update);
    el.addEventListener('keydown', e=>{
      if(!box) return;
      if(e.key==='ArrowDown'){ active=Math.min(items.length-1,active+1); e.preventDefault(); render(currentQuery()||{start:0,end:0}); }
      else if(e.key==='ArrowUp'){ active=Math.max(0,active-1); e.preventDefault(); render(currentQuery()||{start:0,end:0}); }
      else if((e.key==='Enter'||e.key==='Tab') && active>=0){ const cq=currentQuery(); if(cq){ e.preventDefault(); pick(active,cq); } }
      else if(e.key==='Escape'){ close(); }
    });
    el.addEventListener('blur', ()=>setTimeout(close,150));
  }

  /* ---------- Communes du Jura (exhaustif, incl. Moutier rattaché en 2026) ----------
     Communes officielles + principaux villages/localités (fusions). */
  const COMMUNES = [
    'Alle','Asuel','La Baroche','Bassecourt','Belprahon','Berlincourt','Beurnevésin','Boécourt',
    'Boncourt','Bonfol','Bourrignon','Bressaucourt','Les Breuleux','Buix','Bure','Charmoille',
    'Châtillon','La Chaux-des-Breuleux','Chevenez','Clos du Doubs','Cœuve','Corban','Cornol',
    'Courchapoix','Courchavon','Courfaivre','Courgenay','Courrendlin','Courroux','Courtedoux',
    'Courtemaîche','Courtételle','Damphreux','Damphreux-Lugnez','Damvant','Delémont','Develier',
    'Ederswiler','Les Enfers','Épauvillers','Épiquerez','Fahy','Fontenais','Fregiécourt',
    'Les Genevez','Glovelier','Goumois','Grandfontaine','Haute-Ajoie','Haute-Sorne','Lajoux',
    'Lugnez','Mervelier','Mettembert','Miécourt','Montfaucon','Montignez','Montmelon','Montsevelier',
    'Mormont','Moutier','Movelier','Le Noirmont','Ocourt','Pleigne','Pleujouse','Les Pommerats',
    'Porrentruy','Réclère','Rebeuvelier','Roche-d\'Or','Rocourt','Rossemaison','Saignelégier',
    'Saint-Brais','Saint-Ursanne','Saulcy','Séprais','Seleute','Soubey','Soulce','Soyhières',
    'Undervelier','Vendlincourt','Vermes','Vicques'
  ];
  /* Remplit un <select> de communes. opts.first = libellé d'option vide en tête ;
     opts.selected = valeur présélectionnée (ajoutée si absente de la liste). */
  function fillCommuneSelect(sel, opts={}){
    if(!sel) return;
    const selected = opts.selected || '';
    let list = COMMUNES.slice();
    if(selected && !list.includes(selected)) list.unshift(selected);
    let html = '';
    if(opts.first!==undefined) html += `<option value="">${esc(opts.first)}</option>`;
    html += list.map(c=>`<option${c===selected?' selected':''}>${esc(c)}</option>`).join('');
    html += '<option>Autre commune du Jura</option>';
    sel.innerHTML = html;
  }

  function toast(msg){
    let t=document.querySelector('.toast');
    if(!t){t=document.createElement('div');t.className='toast';document.body.appendChild(t);}
    t.textContent=msg; requestAnimationFrame(()=>t.classList.add('show'));
    clearTimeout(t._h); t._h=setTimeout(()=>t.classList.remove('show'),2600);
  }

  /* ---------- Compression image -> Blob (pour upload Storage) ---------- */
  function fileToBlob(file, maxW=1280, quality=0.82){
    return new Promise((resolve,reject)=>{
      if(!file || !file.type.startsWith('image/')) return reject('Fichier non image');
      const reader=new FileReader();
      reader.onload=()=>{
        const img=new Image();
        img.onload=()=>{
          const scale=Math.min(1, maxW/img.width);
          const w=Math.round(img.width*scale), h=Math.round(img.height*scale);
          const cv=document.createElement('canvas'); cv.width=w; cv.height=h;
          cv.getContext('2d').drawImage(img,0,0,w,h);
          cv.toBlob(b=> b?resolve(b):reject('Conversion échouée'), 'image/jpeg', quality);
        };
        img.onerror=()=>reject('Image illisible'); img.src=reader.result;
      };
      reader.onerror=()=>reject('Lecture échouée'); reader.readAsDataURL(file);
    });
  }

  /* ---------- Session / cache du profil courant ---------- */
  let _me = null;   // profil de l'utilisateur connecté (mis en cache)

  async function loadMe(){
    const { data:{ user } } = await sb.auth.getUser();
    if(!user){ _me=null; return null; }
    const { data } = await sb.from('profiles').select('*').eq('id', user.id).single();
    _me = data ? {
      id:data.id, email:user.email, name:data.name, town:data.town,
      bio:data.bio||'', avatar:data.avatar_url, cover:data.cover_url,
      is_pro:data.is_pro, is_admin:data.is_admin, is_banned:data.is_banned, joined:data.created_at,
      email_notifications: data.email_notifications!==false,  // compat
      email_mode: data.email_mode || 'instant'                // 'instant' | 'daily' | 'off'
    } : null;
    return _me;
  }
  const user = () => _me;   // synchrone, renvoie le cache (appeler requireAuth d'abord)

  async function requireAuth(){
    await loadMe();
    if(!_me){ location.href='connexion.html'; return false; }
    if(_me.is_banned){
      await sb.auth.signOut();
      _me=null;
      location.href='banni.html';
      return false;
    }
    return true;
  }

  /* ============================================================
     AUTH
     ============================================================ */
  async function register({name, town, email, password}){
    const { data, error } = await sb.auth.signUp({
      email, password,
      options:{ data:{ name, town } }   // récupérés par le trigger handle_new_user
    });
    if(error) return {ok:false, msg: traduireErreur(error.message)};
    // Selon les réglages Supabase, la session peut être directe ou demander confirmation e-mail
    if(data.session){ await loadMe(); return {ok:true, confirm:false}; }
    return {ok:true, confirm:true};   // e-mail de confirmation envoyé
  }

  async function login({email, password}){
    const { error } = await sb.auth.signInWithPassword({ email, password });
    if(error) return {ok:false, msg: traduireErreur(error.message)};
    await loadMe();
    return {ok:true};
  }

  async function logout(){ await sb.auth.signOut(); location.href='index.html'; }

  /* ---------- Compte ---------- */
  async function updateEmail(email){
    const { error } = await sb.auth.updateUser({ email });
    return error ? {ok:false, msg:traduireErreur(error.message)} : {ok:true};
  }
  async function updatePassword(password){
    const { error } = await sb.auth.updateUser({ password });
    return error ? {ok:false, msg:traduireErreur(error.message)} : {ok:true};
  }
  async function deleteAccount(){
    const { error } = await sb.rpc('delete_my_account');
    if(error) return {ok:false, msg:error.message};
    await sb.auth.signOut();
    return {ok:true};
  }
  async function setEmailNotifications(on){
    if(!_me) return {ok:false};
    const { error } = await sb.from('profiles').update({email_notifications:!!on}).eq('id', _me.id);
    if(error) return {ok:false, msg:error.message};
    _me.email_notifications=!!on;
    return {ok:true};
  }
  /* ---- Notifications push (Web Push) ---- */
  async function savePushSubscription({endpoint, p256dh, auth}){
    if(!_me) return {ok:false};
    const { error } = await sb.from('push_subscriptions')
      .upsert({ user_id:_me.id, endpoint, p256dh, auth }, { onConflict:'endpoint' });
    return error ? {ok:false, msg:error.message} : {ok:true};
  }
  async function deletePushSubscription(endpoint){
    if(!endpoint) return;
    await sb.from('push_subscriptions').delete().eq('endpoint', endpoint);
  }

  /* mode = 'instant' | 'daily' | 'off' (garde email_notifications cohérent) */
  async function setEmailMode(mode){
    if(!_me) return {ok:false};
    if(!['instant','daily','off'].includes(mode)) mode='instant';
    const { error } = await sb.from('profiles')
      .update({ email_mode:mode, email_notifications: mode!=='off' }).eq('id', _me.id);
    if(error) return {ok:false, msg:error.message};
    _me.email_mode=mode; _me.email_notifications = mode!=='off';
    return {ok:true};
  }

  function traduireErreur(m){
    if(/already registered/i.test(m)) return "Un compte existe déjà avec cet e-mail.";
    if(/Invalid login/i.test(m)) return "E-mail ou mot de passe incorrect.";
    if(/at least 6/i.test(m)) return "Mot de passe trop court (min. 6 caractères).";
    if(/confirm/i.test(m)) return "Confirme ton e-mail avant de te connecter.";
    return m;
  }

  /* ============================================================
     PROFIL
     ============================================================ */
  async function updateProfile(patch){
    if(!_me) return {ok:false};
    const row = {};
    if(patch.name!==undefined)   row.name=patch.name;
    if(patch.town!==undefined)   row.town=patch.town;
    if(patch.bio!==undefined)    row.bio=patch.bio;
    if(patch.avatar!==undefined) row.avatar_url=patch.avatar;
    if(patch.cover!==undefined)  row.cover_url=patch.cover;
    const { error } = await sb.from('profiles').update(row).eq('id', _me.id);
    if(error) return {ok:false, msg:error.message};
    await loadMe();
    return {ok:true};
  }

  /* Upload d'une image dans un bucket Storage, renvoie l'URL publique */
  async function uploadImage(bucket, file, maxW, quality){
    const blob = await fileToBlob(file, maxW, quality);
    return uploadBlob(bucket, blob);
  }

  /* Upload d'un Blob déjà préparé (ex: sortie de cropImage) */
  async function uploadBlob(bucket, blob){
    const path = `${_me.id}/${Date.now()}.jpg`;
    const { error } = await sb.storage.from(bucket).upload(path, blob, {contentType:'image/jpeg', upsert:true});
    if(error) throw error;
    const { data } = sb.storage.from(bucket).getPublicUrl(path);
    return data.publicUrl;
  }

  /* Upload d'une vidéo (telle quelle, pas de transcodage) -> URL publique */
  async function uploadVideo(file){
    if(!file || !_me) throw 'invalide';
    const ext=(file.name.split('.').pop()||'mp4').toLowerCase().replace(/[^a-z0-9]/g,'') || 'mp4';
    const path=`${_me.id}/${Date.now()}.${ext}`;
    const { error } = await sb.storage.from('posts').upload(path, file, {contentType:file.type||'video/mp4', upsert:true});
    if(error) throw error;
    const { data } = sb.storage.from('posts').getPublicUrl(path);
    return data.publicUrl;
  }

  /* ------------------------------------------------------------
     Recadrage interactif (façon Facebook) : ouvre une modale où
     l'utilisateur déplace / zoome l'image, puis renvoie un Blob JPEG
     déjà cadré. Résout null si annulé.
       opts.aspect : largeur/hauteur de la zone (1 = carré, 2.7 = bannière)
       opts.round  : aperçu rond (avatar) — le rendu reste un carré plein
       opts.outW   : largeur de sortie en px
       opts.title  : titre de la modale
     ------------------------------------------------------------ */
  function cropImage(file, opts={}){
    return new Promise((resolve)=>{
      if(!file || !file.type || !file.type.startsWith('image/')){ toast('Fichier non image'); resolve(null); return; }
      const aspect = opts.aspect || 1;
      const round  = !!opts.round;
      const outW   = opts.outW || 1024;
      const title  = opts.title || 'Repositionne la photo';
      const reader = new FileReader();
      reader.onload = ()=>{
        const img = new Image();
        img.onload = ()=> openUI(img);
        img.onerror = ()=>{ toast('Image illisible'); resolve(null); };
        img.src = reader.result;
      };
      reader.onerror = ()=>{ toast('Lecture échouée'); resolve(null); };
      reader.readAsDataURL(file);

      function openUI(img){
        const vw = Math.min(window.innerWidth-48, 380);
        const vh = Math.round(vw/aspect);
        const baseScale = Math.max(vw/img.naturalWidth, vh/img.naturalHeight);
        let zoom=1, dispW=0, dispH=0, panX=0, panY=0;

        const bg=document.createElement('div');
        bg.style.cssText='position:fixed;inset:0;background:rgba(26,20,22,.7);z-index:500;display:flex;align-items:center;justify-content:center;padding:16px';
        const panel=document.createElement('div');
        panel.style.cssText='background:#fff;border-radius:18px;max-width:440px;width:100%;padding:18px;box-shadow:0 18px 50px rgba(0,0,0,.3)';
        panel.innerHTML=`<h3 style="font-family:'Plus Jakarta Sans';font-size:1.1rem;margin:0 0 4px">${esc(title)}</h3>
          <p style="color:#5C5258;font-size:.85rem;margin:0 0 14px">Fais glisser pour repositionner, et utilise le curseur pour zoomer.</p>`;
        const vp=document.createElement('div');
        vp.style.cssText=`position:relative;overflow:hidden;width:${vw}px;height:${vh}px;margin:0 auto;background:#000;border-radius:${round?'50%':'12px'};touch-action:none;cursor:grab;user-select:none`;
        const pic=document.createElement('img');
        pic.src=img.src; pic.draggable=false;
        pic.style.cssText='position:absolute;left:0;top:0;max-width:none;pointer-events:none;will-change:transform';
        vp.appendChild(pic);
        const zr=document.createElement('input');
        zr.type='range'; zr.min='1'; zr.max='4'; zr.step='0.01'; zr.value='1';
        zr.style.cssText='width:100%;margin:14px 0;accent-color:#E11D2A';
        const btns=document.createElement('div');
        btns.style.cssText='display:flex;gap:10px;justify-content:flex-end';
        btns.innerHTML='<button class="btn btn-ghost btn-sm" data-act="cancel">Annuler</button><button class="btn btn-primary btn-sm" data-act="ok">Enregistrer</button>';
        panel.appendChild(vp); panel.appendChild(zr); panel.appendChild(btns); bg.appendChild(panel);
        document.body.appendChild(bg);

        function apply(){ pic.style.width=dispW+'px'; pic.style.height=dispH+'px'; pic.style.transform=`translate(${panX}px,${panY}px)`; }
        function clamp(){ panX=Math.min(0,Math.max(vw-dispW,panX)); panY=Math.min(0,Math.max(vh-dispH,panY)); apply(); }
        function recompute(keepCenter){
          const cx = keepCenter && dispW ? (vw/2 - panX)/dispW : 0.5;
          const cy = keepCenter && dispH ? (vh/2 - panY)/dispH : 0.5;
          dispW = img.naturalWidth*baseScale*zoom;
          dispH = img.naturalHeight*baseScale*zoom;
          panX = vw/2 - cx*dispW; panY = vh/2 - cy*dispH;
          clamp();
        }
        recompute(false);

        let dragging=false, sx=0, sy=0, px0=0, py0=0;
        vp.addEventListener('pointerdown',e=>{ dragging=true; sx=e.clientX; sy=e.clientY; px0=panX; py0=panY; try{vp.setPointerCapture(e.pointerId);}catch(_){} vp.style.cursor='grabbing'; });
        vp.addEventListener('pointermove',e=>{ if(!dragging)return; panX=px0+(e.clientX-sx); panY=py0+(e.clientY-sy); clamp(); });
        vp.addEventListener('pointerup',()=>{ dragging=false; vp.style.cursor='grab'; });
        vp.addEventListener('pointercancel',()=>{ dragging=false; });
        zr.addEventListener('input',()=>{ zoom=parseFloat(zr.value)||1; recompute(true); });

        function close(result){ if(bg.parentNode) document.body.removeChild(bg); resolve(result); }
        btns.querySelector('[data-act="cancel"]').addEventListener('click',()=>close(null));
        bg.addEventListener('click',e=>{ if(e.target===bg) close(null); });
        btns.querySelector('[data-act="ok"]').addEventListener('click',()=>{
          const oh=Math.round(outW/aspect), k=outW/vw;
          const cv=document.createElement('canvas'); cv.width=outW; cv.height=oh;
          const ctx=cv.getContext('2d');
          ctx.fillStyle='#000'; ctx.fillRect(0,0,outW,oh);
          ctx.drawImage(img, panX*k, panY*k, dispW*k, dispH*k);
          cv.toBlob(b=>close(b), 'image/jpeg', 0.85);
        });
      }
    });
  }

  /* ============================================================
     PUBLICATIONS
     ============================================================ */
  /* Fil paginé par curseur : opts.before = created_at du dernier post chargé
     (renvoie les plus anciens que `before`), opts.limit = taille de page. */
  async function posts({before=null, limit=100, town=null}={}){
    let q = sb
      .from('posts')
      .select(`id, text, tag, image_url, images, created_at, author_id, shared_post_id,
               author:profiles!author_id ( name, town, avatar_url ),
               shared:posts!shared_post_id ( id, text, image_url, images, created_at, author_id, author:profiles!author_id ( name, avatar_url ) ),
               video_url, link_url, link_title, link_desc, link_image, link_site, likes ( user_id, type ), poll_options, poll_votes ( user_id, choice ),
               comments ( id, text, created_at, author_id, parent_id, author:profiles!author_id ( name, avatar_url ), comment_likes ( user_id ) )`)
      .is('group_id', null);
    if(town) q = q.eq('town', town);
    if(before) q = q.lt('created_at', before);
    q = q.order('created_at', {ascending:false}).limit(limit);
    const { data, error } = await q;
    if(error){ console.error(error); return []; }
    await loadBlocked();
    const blocked=blockedIds();
    return (data||[]).map(mapPost).filter(p=>!blocked.includes(p.authorEmail));
  }

  /* Aperçu d'une publication repartagée (carte intégrée) */
  function mapSharedPost(s){
    if(!s) return null;
    let imgs = Array.isArray(s.images) ? s.images.filter(Boolean) : [];
    if(!imgs.length && s.image_url) imgs=[s.image_url];
    return {
      id:s.id, text:s.text||'', image:imgs[0]||null, ts:s.created_at,
      authorEmail:s.author_id, author:s.author?.name||'Membre',
      authorAvatar:s.author?.avatar_url||null
    };
  }

  function mapPost(p){
    const rx=(p.likes||[]);
    const likedBy=rx.map(l=>l.user_id);
    const myReaction = rx.find(l=>l.user_id===_me?.id)?.type || null;
    const reactionCounts={};
    rx.forEach(l=>{ const t=l.type||'like'; reactionCounts[t]=(reactionCounts[t]||0)+1; });
    let imgs = Array.isArray(p.images) ? p.images.filter(Boolean) : [];
    if(!imgs.length && p.image_url) imgs=[p.image_url];   // compat ancien format
    let poll=null;
    if(Array.isArray(p.poll_options) && p.poll_options.length>=2){
      const opts=p.poll_options;
      const counts=opts.map(()=>0);
      (p.poll_votes||[]).forEach(v=>{ if(v.choice>=0 && v.choice<counts.length) counts[v.choice]++; });
      poll={
        options:opts, counts,
        total:(p.poll_votes||[]).length,
        myChoice:(p.poll_votes||[]).find(v=>v.user_id===_me?.id)?.choice ?? null
      };
    }
    const linkPreview = p.link_url ? {
      url:p.link_url, title:p.link_title||'', desc:p.link_desc||'', image:p.link_image||null, site:p.link_site||''
    } : null;
    return {
      id:p.id, text:p.text, tag:p.tag, image:imgs[0]||null, images:imgs, video:p.video_url||null, linkPreview, ts:p.created_at, poll,
      authorEmail:p.author_id,
      author:p.author?.name||'Membre', town:p.author?.town||'', authorAvatar:p.author?.avatar_url||null,
      likes:likedBy.length, likedBy, myReaction, reactionCounts,
      sharedId:p.shared_post_id||null,
      shared: mapSharedPost(p.shared),
      comments:(p.comments||[]).map(c=>({
        id:c.id,
        authorId:c.author_id,
        parentId:c.parent_id||null,
        author:c.author?.name||'Membre',
        avatar:c.author?.avatar_url||null,
        text:c.text,
        ts:c.created_at,
        likes:(c.comment_likes||[]).length,
        liked:(c.comment_likes||[]).some(l=>l.user_id===_me?.id)
      }))
    };
  }

  /* Upload de plusieurs images -> tableau d'URLs (max 6) */
  async function uploadImages(bucket, files, maxW=1280, quality=0.82){
    const list=[...files].slice(0,6);
    const urls=[];
    for(const f of list){
      try{ urls.push(await uploadImage(bucket, f, maxW, quality)); }
      catch(e){ console.error(e); }
    }
    return urls;
  }

  async function addPost({text, tag, image, images, sharedPostId, pollOptions, video}){
    if(!_me) return;
    let urls=[];
    if(images && images.length) urls=await uploadImages('posts', images, 1280, 0.82);
    else if(image){ try{ urls=[await uploadImage('posts', image, 1280, 0.82)]; }catch(e){ toast('Photo trop lourde'); } }
    let videoUrl=null;
    if(video){ try{ videoUrl=await uploadVideo(video); }catch(e){ console.error(e); toast('Vidéo refusée (trop lourde ?)'); } }
    const poll = (pollOptions && pollOptions.length>=2) ? pollOptions.slice(0,6) : null;
    const link = await fetchLinkPreview(text, {skip: !!sharedPostId});
    const { error } = await sb.from('posts').insert({
      author_id:_me.id, text, tag:tag||'Général', town:_me.town||null,
      image_url:urls[0]||null, images:urls, video_url:videoUrl,
      shared_post_id: sharedPostId||null,
      poll_options: poll,
      link_url:link.url, link_title:link.title, link_desc:link.desc, link_image:link.image, link_site:link.site
    });
    if(error) toast(error.message);
  }

  /* Détecte la 1ère URL d'un texte et récupère son aperçu Open Graph
     via l'Edge Function « og-preview ». Renvoie des champs vides si pas
     d'URL / fonction absente (l'app reste fonctionnelle). */
  async function fetchLinkPreview(text, opts={}){
    const empty={url:null,title:null,desc:null,image:null,site:null};
    if(opts.skip) return empty;
    const m=(text||'').match(/https?:\/\/[^\s]+/);
    if(!m) return empty;
    try{
      const { data, error } = await sb.functions.invoke('og-preview', { body:{ url:m[0] } });
      if(error || !data) return empty;
      if(!data.title && !data.image) return empty;   // pas d'aperçu exploitable
      return { url:m[0], title:data.title||null, desc:data.description||null, image:data.image||null, site:data.site||null };
    }catch(e){ return empty; }
  }

  /* Voter / changer son vote à un sondage (choice = index de l'option) */
  async function votePoll(postId, choice){
    if(!_me) return {ok:false};
    const { error } = await sb.from('poll_votes')
      .upsert({post_id:postId, user_id:_me.id, choice}, {onConflict:'post_id,user_id'});
    return error ? {ok:false, msg:error.message} : {ok:true};
  }
  async function removePollVote(postId){
    if(!_me) return;
    await sb.from('poll_votes').delete().eq('post_id',postId).eq('user_id',_me.id);
  }

  /* Repartager une publication dans son fil (avec un mot optionnel) */
  async function sharePost(postId, text=''){
    return addPost({text:text||'', tag:'Partage', sharedPostId:postId});
  }

  /* Une seule publication (permalien) avec ses commentaires */
  async function getPost(pid){
    const { data, error } = await sb
      .from('posts')
      .select(`id, text, tag, image_url, images, created_at, author_id, shared_post_id,
               author:profiles!author_id ( name, town, avatar_url ),
               shared:posts!shared_post_id ( id, text, image_url, images, created_at, author_id, author:profiles!author_id ( name, avatar_url ) ),
               video_url, link_url, link_title, link_desc, link_image, link_site, likes ( user_id, type ), poll_options, poll_votes ( user_id, choice ),
               comments ( id, text, created_at, author_id, parent_id, author:profiles!author_id ( name, avatar_url ), comment_likes ( user_id ) )`)
      .eq('id', pid).single();
    if(error){ console.error(error); return null; }
    return mapPost(data);
  }

  async function deletePost(pid){
    if(!_me) return;
    await sb.from('posts').delete().eq('id', pid).eq('author_id', _me.id);
  }

  /* Modifier sa publication / son commentaire */
  async function editPost(pid, text){
    if(!_me) return {ok:false};
    const { error } = await sb.from('posts').update({text}).eq('id', pid).eq('author_id', _me.id);
    return error ? {ok:false, msg:error.message} : {ok:true};
  }
  async function editComment(cid, text){
    if(!_me) return {ok:false};
    const { error } = await sb.from('comments').update({text}).eq('id', cid).eq('author_id', _me.id);
    return error ? {ok:false, msg:error.message} : {ok:true};
  }

  async function toggleLike(pid){
    if(!_me) return;
    const { data } = await sb.from('likes').select('post_id').eq('post_id',pid).eq('user_id',_me.id).maybeSingle();
    if(data) await sb.from('likes').delete().eq('post_id',pid).eq('user_id',_me.id);
    else      await sb.from('likes').insert({post_id:pid, user_id:_me.id, type:'like'});
  }
  const isLiked = p => !!_me && (p.likedBy||[]).includes(_me.id);

  /* Réactions multiples */
  const REACTIONS=[
    {type:'like', emoji:'👍', label:"J'aime"},
    {type:'love', emoji:'❤️', label:"J'adore"},
    {type:'haha', emoji:'😆', label:'Haha'},
    {type:'wow',  emoji:'😮', label:'Waouh'},
    {type:'sad',  emoji:'😢', label:'Triste'}
  ];
  function reactionMeta(type){ return REACTIONS.find(r=>r.type===type) || REACTIONS[0]; }

  /* Définir / changer / retirer (type=null) sa réaction à une publication */
  async function reactPost(pid, type){
    if(!_me) return;
    if(!type){ await sb.from('likes').delete().eq('post_id',pid).eq('user_id',_me.id); return; }
    await sb.from('likes').upsert({post_id:pid, user_id:_me.id, type}, {onConflict:'post_id,user_id'});
  }

  async function addComment(pid, text, parentId){
    if(!_me) return;
    await sb.from('comments').insert({post_id:pid, author_id:_me.id, text, parent_id:parentId||null});
  }

  /* Aimer / ne plus aimer un commentaire (toggle) */
  async function toggleCommentLike(commentId){
    if(!_me) return;
    const { data } = await sb.from('comment_likes')
      .select('comment_id').eq('comment_id', commentId).eq('user_id', _me.id).maybeSingle();
    if(data) await sb.from('comment_likes').delete().eq('comment_id', commentId).eq('user_id', _me.id);
    else      await sb.from('comment_likes').insert({comment_id:commentId, user_id:_me.id});
  }

  /* ============================================================
     ÉVÉNEMENTS
     ============================================================ */
  function mapEvent(e){
    const d = e.starts_at ? new Date(e.starts_at) : null;
    const att=e.attendees||[];
    return {
      id:e.id, title:e.title, town:e.town, description:e.description||'', cover:e.cover_url||null,
      ts:e.starts_at, endTs:e.ends_at||null, images:Array.isArray(e.images)?e.images.filter(Boolean):[],
      creatorId:e.creator_id, mine:e.creator_id===_me?.id,
      day: d? String(d.getDate()).padStart(2,'0') : '–',
      month: d? d.toLocaleDateString('fr-CH',{month:'short'}) : '',
      going: att.filter(a=>(a.status||'going')==='going').length,
      interested: att.filter(a=>a.status==='interested').length,
      goingBy: att.filter(a=>(a.status||'going')==='going').map(a=>a.user_id),
      myStatus: att.find(a=>a.user_id===_me?.id)?.status || null
    };
  }
  async function events({town=''}={}){
    let q = sb
      .from('events')
      .select(`id, title, town, starts_at, ends_at, description, cover_url, images, creator_id, attendees:event_attendees ( user_id, status )`)
      .order('starts_at', {ascending:true});
    if(town) q = q.eq('town', town);
    const { data, error } = await q;
    if(error){ console.error(error); return []; }
    return (data||[]).map(mapEvent);
  }
  async function getEvent(eid){
    const { data } = await sb.from('events')
      .select(`id, title, town, starts_at, ends_at, description, cover_url, images, creator_id,
               creator:profiles!creator_id ( name, avatar_url ),
               attendees:event_attendees ( user_id, status, profiles:profiles!user_id ( name, avatar_url ) )`)
      .eq('id', eid).single();
    if(!data) return null;
    const ev=mapEvent(data);
    ev.creatorName=data.creator?.name||'Membre';
    ev.attendeeList=(data.attendees||[]).map(a=>({ id:a.user_id, status:a.status||'going', name:a.profiles?.name||'Membre', avatar:a.profiles?.avatar_url||null }));
    return ev;
  }
  /* Modifier un événement (créateur — RLS) */
  async function updateEvent(eid, fields){
    const { error } = await sb.from('events').update(fields).eq('id', eid);
    return error ? {ok:false, msg:error.message} : {ok:true};
  }
  async function updateEventCover(eid, fileOrBlob){
    const isFile = fileOrBlob instanceof File;
    const url = isFile ? await uploadImage('covers', fileOrBlob, 1400, 0.78) : await uploadBlob('covers', fileOrBlob);
    return updateEvent(eid, {cover_url:url});
  }
  async function deleteEvent(eid){
    const { error } = await sb.from('events').delete().eq('id', eid);
    return error ? {ok:false, msg:error.message} : {ok:true};
  }

  /* RSVP : status = 'going' | 'interested' | null (retire) */
  async function setEventRsvp(eid, status){
    if(!_me) return;
    if(!status){ await sb.from('event_attendees').delete().eq('event_id',eid).eq('user_id',_me.id); return; }
    await sb.from('event_attendees').upsert({event_id:eid, user_id:_me.id, status}, {onConflict:'event_id,user_id'});
  }
  async function toggleGoing(eid){
    if(!_me) return false;
    const { data } = await sb.from('event_attendees').select('event_id').eq('event_id',eid).eq('user_id',_me.id).maybeSingle();
    if(data){ await sb.from('event_attendees').delete().eq('event_id',eid).eq('user_id',_me.id); return false; }
    await sb.from('event_attendees').insert({event_id:eid, user_id:_me.id, status:'going'}); return true;
  }
  const isGoing = e => !!_me && (e.goingBy||[]).includes(_me.id);

  /* Discussion d'un événement */
  async function eventComments(eid){
    const { data } = await sb.from('event_comments')
      .select(`id, text, created_at, author_id, author:profiles!author_id ( name, avatar_url )`)
      .eq('event_id', eid).order('created_at',{ascending:true});
    return (data||[]).map(c=>({ id:c.id, authorId:c.author_id, author:c.author?.name||'Membre',
      avatar:c.author?.avatar_url||null, text:c.text, ts:c.created_at }));
  }
  async function addEventComment(eid, text){
    if(!_me) return;
    await sb.from('event_comments').insert({event_id:eid, author_id:_me.id, text});
  }
  async function deleteEventComment(cid){
    if(!_me) return;
    await sb.from('event_comments').delete().eq('id', cid).eq('author_id', _me.id);
  }

  async function createEvent({title, town, starts_at, ends_at, description, cover, images}){
    if(!_me) return {ok:false, msg:'Non connecté'};
    let coverUrl=null, imgUrls=[];
    if(cover){ try{ coverUrl = cover instanceof File ? await uploadImage('covers',cover,1400,0.78) : await uploadBlob('covers',cover); }catch(e){} }
    if(images && images.length){ try{ imgUrls=await uploadImages('posts', images, 1280, 0.82); }catch(e){} }
    const { data, error } = await sb.from('events').insert({
      title, town, starts_at, ends_at:ends_at||null, description, creator_id:_me.id,
      cover_url:coverUrl, images:imgUrls
    }).select().single();
    if(error) return {ok:false, msg:error.message};
    return {ok:true, id:data.id};
  }

  /* ============================================================
     NOTIFICATIONS
     ============================================================ */
  async function notifications(){
    if(!_me) return [];
    const { data, error } = await sb
      .from('notifications')
      .select(`id, type, read, created_at, post_id, actor_id,
               actor:profiles!actor_id ( name, avatar_url )`)
      .eq('user_id', _me.id)
      .order('created_at', {ascending:false})
      .limit(50);
    if(error){ console.error(error); return []; }
    return (data||[]).map(n=>({
      id:n.id, type:n.type, read:n.read, ts:n.created_at, postId:n.post_id,
      actorName:n.actor?.name||'Quelqu\'un', actorAvatar:n.actor?.avatar_url||null,
      link: notifLink(n.type, n.post_id, n.actor_id)
    }));
  }

  /* Où mène une notification quand on clique dessus (lien profond) */
  function notifLink(type, postId, actorId){
    if(type==='friend_request' || type==='friend_accept') return 'amis.html';
    if(type==='message') return 'messages.html';
    if(type==='follow')  return actorId ? ('membre.html?id='+actorId) : 'fil.html';
    if((type==='like' || type==='comment' || type==='mention') && postId) return 'post.html?id='+postId;
    return 'fil.html';
  }

  async function unreadCount(){
    if(!_me) return 0;
    const { count } = await sb
      .from('notifications')
      .select('id', {count:'exact', head:true})
      .eq('user_id', _me.id).eq('read', false);
    return count||0;
  }

  async function markAllRead(){
    if(!_me) return;
    await sb.from('notifications').update({read:true}).eq('user_id',_me.id).eq('read',false);
  }

  /* Abonnement temps réel aux nouvelles notifications me concernant.
     onNew() est appelé à chaque nouvelle notif (pour mettre à jour la cloche). */
  function subscribeNotifications(onNew){
    if(!_me) return ()=>{};
    const ch = sb.channel('notif-'+_me.id)
      .on('postgres_changes',
        {event:'INSERT', schema:'public', table:'notifications', filter:`user_id=eq.${_me.id}`},
        ()=> onNew())
      .subscribe();
    return ()=> sb.removeChannel(ch);
  }

  /* ============================================================
     ABONNEMENTS (follows)
     ============================================================ */
  async function follow(targetId){
    if(!_me || targetId===_me.id) return;
    await sb.from('follows').insert({follower_id:_me.id, followee_id:targetId});
  }
  async function unfollow(targetId){
    if(!_me) return;
    await sb.from('follows').delete().eq('follower_id',_me.id).eq('followee_id',targetId);
  }
  async function isFollowing(targetId){
    if(!_me) return false;
    const { data } = await sb.from('follows').select('follower_id')
      .eq('follower_id',_me.id).eq('followee_id',targetId).maybeSingle();
    return !!data;
  }
  async function followCounts(profileId){
    const [{count:followers},{count:following}] = await Promise.all([
      sb.from('follows').select('followee_id',{count:'exact',head:true}).eq('followee_id',profileId),
      sb.from('follows').select('follower_id',{count:'exact',head:true}).eq('follower_id',profileId)
    ]);
    return {followers:followers||0, following:following||0};
  }

  /* Libellé lisible d'une notification */
  function notifText(type){
    if(type==='like')    return "a aimé ta publication";
    if(type==='comment') return "a commenté ta publication";
    if(type==='follow')  return "s'est abonné·e à toi";
    if(type==='message') return "t'a envoyé un message";
    if(type==='friend_request') return "t'a envoyé une demande d'ami";
    if(type==='friend_accept')  return "a accepté ta demande d'ami";
    if(type==='mention')        return "t'a mentionné·e";
    return "a interagi avec toi";
  }

  /* ============================================================
     MESSAGERIE
     ============================================================ */
  /* Liste des membres (pour démarrer une conversation / annuaire) */
  async function members(search=''){
    let q = sb.from('profiles').select('id, name, town, avatar_url').limit(50);
    if(search) q = q.ilike('name', `%${search}%`);
    const { data } = await q;
    return (data||[]).filter(m=>m.id!==_me?.id).map(m=>({
      id:m.id, name:m.name, town:m.town, avatar:m.avatar_url
    }));
  }

  /* Trouve une conversation 1-à-1 existante avec `otherId`, sinon la crée.
     RÈGLE : on ne peut écrire qu'à un ami. */
  async function openConversationWith(otherId){
    if(!_me) return null;
    if(!(await areFriends(otherId))){
      toast('Tu peux seulement écrire à tes amis');
      return {error:'not_friends'};
    }
    // Conversations dont je suis membre
    const { data:mine } = await sb.from('conversation_members')
      .select('conversation_id').eq('user_id', _me.id);
    const myConvIds=(mine||[]).map(r=>r.conversation_id);
    if(myConvIds.length){
      // Parmi elles, lesquelles ont aussi l'autre personne, en 1-à-1 ?
      const { data:shared } = await sb.from('conversation_members')
        .select('conversation_id').eq('user_id', otherId).in('conversation_id', myConvIds);
      for(const r of (shared||[])){
        const { count } = await sb.from('conversation_members')
          .select('user_id',{count:'exact',head:true}).eq('conversation_id', r.conversation_id);
        if(count===2) return r.conversation_id;   // conversation 1-à-1 trouvée
      }
    }
    // Sinon : créer
    const { data:conv, error } = await sb.from('conversations').insert({is_group:false}).select().single();
    if(error){ console.error(error); return null; }
    await sb.from('conversation_members').insert([
      {conversation_id:conv.id, user_id:_me.id},
      {conversation_id:conv.id, user_id:otherId}
    ]);
    return conv.id;
  }

  /* Contacter quelqu'un SANS être amis (Marché) : crée/retrouve la
     conversation 1-à-1 via la fonction dédiée et renvoie son id. */
  async function contactSeller(otherId){
    if(!_me || !otherId) return null;
    const { data, error } = await sb.rpc('contact_user', { other_id: otherId });
    if(error){ console.error(error); toast('Impossible de contacter ce membre'); return null; }
    return data;
  }

  /* Mes conversations (1-à-1 et groupes), avec dernier message */
  async function conversations(){
    if(!_me) return [];
    const { data:mine } = await sb.from('conversation_members')
      .select('conversation_id').eq('user_id', _me.id);
    const ids=(mine||[]).map(r=>r.conversation_id);
    if(!ids.length) return [];
    const { data:convRows } = await sb.from('conversations').select('id, is_group, title').in('id', ids);
    const meta={}; (convRows||[]).forEach(c=>meta[c.id]=c);
    const { data:allMembers } = await sb.from('conversation_members')
      .select('conversation_id, user_id, profiles!user_id ( name, avatar_url )')
      .in('conversation_id', ids);
    const { data:msgs } = await sb.from('messages')
      .select('conversation_id, text, created_at, sender_id')
      .in('conversation_id', ids)
      .order('created_at', {ascending:false});
    const lastByConv={};
    (msgs||[]).forEach(m=>{ if(!lastByConv[m.conversation_id]) lastByConv[m.conversation_id]=m; });
    return ids.map(cid=>{
      const m=meta[cid]||{};
      const others=(allMembers||[]).filter(x=>x.conversation_id===cid && x.user_id!==_me.id);
      const last=lastByConv[cid];
      if(m.is_group){
        const name = (m.title||'').trim() || others.map(o=>o.profiles?.name).filter(Boolean).slice(0,3).join(', ') || 'Groupe';
        return { id:cid, isGroup:true, name, avatar:null, memberCount: others.length+1,
                 lastText:last?.text||'', lastTs:last?.created_at||null };
      }
      const other=others[0];
      return {
        id:cid, isGroup:false,
        name: other?.profiles?.name || 'Conversation',
        avatar: other?.profiles?.avatar_url || null,
        lastText: last?.text || '', lastTs: last?.created_at || null
      };
    }).sort((a,b)=> new Date(b.lastTs||0)-new Date(a.lastTs||0));
  }

  async function messagesOf(convId){
    const { data } = await sb.from('messages')
      .select('id, text, created_at, sender_id, sender:profiles!sender_id ( name, avatar_url )')
      .eq('conversation_id', convId)
      .order('created_at', {ascending:true});
    return (data||[]).map(m=>({
      id:m.id, text:m.text, ts:m.created_at, mine:m.sender_id===_me?.id,
      senderId:m.sender_id, senderName:m.sender?.name||'Membre', senderAvatar:m.sender?.avatar_url||null
    }));
  }

  /* ---- Conversations de groupe ---- */
  async function createGroupConversation(title, ids){
    if(!_me) return {ok:false};
    const { data:conv, error } = await sb.from('conversations')
      .insert({is_group:true, title:(title||'').trim()||'Groupe'}).select().single();
    if(error) return {ok:false, msg:error.message};
    const rows=[{conversation_id:conv.id, user_id:_me.id}].concat((ids||[]).map(id=>({conversation_id:conv.id, user_id:id})));
    const { error:e2 } = await sb.from('conversation_members').insert(rows);
    if(e2) return {ok:false, msg:e2.message};
    return {ok:true, id:conv.id};
  }
  async function conversationInfo(convId){
    const { data:c } = await sb.from('conversations').select('id, is_group, title').eq('id', convId).single();
    const { data:mems } = await sb.from('conversation_members')
      .select('user_id, profiles!user_id ( name, avatar_url )').eq('conversation_id', convId);
    return {
      id:convId, isGroup: !!c?.is_group, title: c?.title || '',
      members: (mems||[]).map(m=>({ id:m.user_id, name:m.profiles?.name||'Membre', avatar:m.profiles?.avatar_url||null, mine:m.user_id===_me?.id }))
    };
  }
  async function addConversationMembers(convId, ids){
    if(!ids || !ids.length) return {ok:true};
    const rows=ids.map(id=>({conversation_id:convId, user_id:id}));
    const { error } = await sb.from('conversation_members').upsert(rows, {onConflict:'conversation_id,user_id'});
    return error ? {ok:false, msg:error.message} : {ok:true};
  }
  async function leaveConversation(convId){
    if(!_me) return;
    await sb.from('conversation_members').delete().eq('conversation_id', convId).eq('user_id', _me.id);
  }
  async function renameConversation(convId, title){
    const { error } = await sb.from('conversations').update({title:(title||'').trim()||'Groupe'}).eq('id', convId);
    return error ? {ok:false, msg:error.message} : {ok:true};
  }

  async function sendMessage(convId, text){
    if(!_me) return {error:'no-user'};
    const { error } = await sb.from('messages').insert({conversation_id:convId, sender_id:_me.id, text});
    return { error };
  }

  /* Abonnement temps réel aux nouveaux messages d'une conversation */
  function subscribeMessages(convId, onNew){
    const ch = sb.channel('conv-'+convId)
      .on('postgres_changes',
        {event:'INSERT', schema:'public', table:'messages', filter:`conversation_id=eq.${convId}`},
        payload=>{
          const m=payload.new;
          onNew({id:m.id, text:m.text, ts:m.created_at, mine:m.sender_id===_me?.id, senderId:m.sender_id});
        })
      .subscribe();
    return ()=> sb.removeChannel(ch);   // fonction de désabonnement
  }

  /* Recherche de publications par texte */
  async function searchPosts(q){
    if(!q) return [];
    const { data } = await sb
      .from('posts')
      .select(`id, text, tag, image_url, images, created_at, author_id,
               author:profiles!author_id ( name, town, avatar_url ),
               video_url, link_url, link_title, link_desc, link_image, link_site, likes ( user_id, type ), poll_options, poll_votes ( user_id, choice ),
               comments ( id )`)
      .is('group_id', null)
      .ilike('text', `%${q}%`)
      .order('created_at', {ascending:false})
      .limit(30);
    return (data||[]).map(p=>({
      id:p.id, text:p.text, tag:p.tag, image:p.image_url, ts:p.created_at,
      authorEmail:p.author_id, author:p.author?.name||'Membre',
      town:p.author?.town||'', authorAvatar:p.author?.avatar_url||null,
      likes:(p.likes||[]).length, comments:(p.comments||[]).length
    }));
  }

  /* ============================================================
     AMITIÉS (demandes d'ami réciproques)
     ============================================================ */
  /* Statut d'amitié entre moi et otherId :
     'none' | 'pending_sent' | 'pending_received' | 'friends' */
  async function friendStatus(otherId){
    if(!_me || otherId===_me.id) return {status:'self'};
    const { data } = await sb.from('friendships')
      .select('id, requester_id, addressee_id, status')
      .or(`and(requester_id.eq.${_me.id},addressee_id.eq.${otherId}),and(requester_id.eq.${otherId},addressee_id.eq.${_me.id})`)
      .maybeSingle();
    if(!data) return {status:'none'};
    if(data.status==='accepted') return {status:'friends', id:data.id};
    if(data.requester_id===_me.id) return {status:'pending_sent', id:data.id};
    return {status:'pending_received', id:data.id};
  }

  async function sendFriendRequest(otherId){
    if(!_me || otherId===_me.id) return;
    await sb.from('friendships').insert({requester_id:_me.id, addressee_id:otherId, status:'pending'});
  }
  async function acceptFriend(friendshipId){
    await sb.from('friendships').update({status:'accepted'}).eq('id', friendshipId);
  }
  async function removeFriend(friendshipId){
    await sb.from('friendships').delete().eq('id', friendshipId);
  }

  /* Demandes d'ami reçues en attente (pour moi) */
  async function pendingRequests(){
    if(!_me) return [];
    const { data } = await sb.from('friendships')
      .select(`id, created_at, requester:profiles!requester_id ( id, name, town, avatar_url )`)
      .eq('addressee_id', _me.id).eq('status','pending')
      .order('created_at', {ascending:false});
    return (data||[]).map(r=>({
      id:r.id, ts:r.created_at,
      userId:r.requester?.id, name:r.requester?.name||'Membre',
      town:r.requester?.town||'', avatar:r.requester?.avatar_url||null
    }));
  }

  /* Liste de mes amis (acceptés), des deux côtés de la relation */
  async function friends(profileId){
    const uid = profileId || _me?.id;
    if(!uid) return [];
    const { data } = await sb.from('friendships')
      .select(`id, requester_id, addressee_id,
               requester:profiles!requester_id ( id, name, town, avatar_url ),
               addressee:profiles!addressee_id ( id, name, town, avatar_url )`)
      .or(`requester_id.eq.${uid},addressee_id.eq.${uid}`)
      .eq('status','accepted');
    return (data||[]).map(f=>{
      const other = f.requester_id===uid ? f.addressee : f.requester;
      return {friendshipId:f.id, id:other?.id, name:other?.name||'Membre',
              town:other?.town||'', avatar:other?.avatar_url||null};
    });
  }

  async function friendCount(profileId){
    const uid = profileId || _me?.id;
    if(!uid) return 0;
    const { count } = await sb.from('friendships')
      .select('id',{count:'exact',head:true})
      .or(`requester_id.eq.${uid},addressee_id.eq.${uid}`)
      .eq('status','accepted');
    return count||0;
  }

  /* Vrai si moi et otherId sommes amis (acceptés) */
  async function areFriends(otherId){
    const st = await friendStatus(otherId);
    return st.status === 'friends';
  }

  /* ============================================================
     GROUPES / COMMUNAUTÉS
     ============================================================ */
  async function listGroups(search='', kind='group'){
    let q = sb.from('groups')
      .select(`id, name, description, town, cover_url, owner_id, is_private, kind, category, members:group_members ( user_id, role )`)
      .eq('kind', kind)
      .order('created_at', {ascending:false});
    if(search) q = q.ilike('name', `%${search}%`);
    const { data } = await q;
    return (data||[]).map(g=>mapGroup(g));
  }

  function mapGroup(g){
    const all=(g.members||[]);
    const members=all.filter(m=>m.role!=='pending');
    const myRow=all.find(m=>m.user_id===_me?.id);
    const isOwner = g.owner_id===_me?.id;
    const isAdmin = !!myRow && myRow.role==='admin';
    const toPerson=m=>({
      userId:m.user_id,
      role: m.user_id===g.owner_id ? 'owner' : (m.role||'member'),
      name: m.profiles?.name || 'Membre',
      avatar: m.profiles?.avatar_url || null,
      town: m.profiles?.town || ''
    });
    // Administrateurs affichés : le créateur (owner) + les role='admin'
    const managers = members
      .filter(m=> m.user_id===g.owner_id || m.role==='admin')
      .map(toPerson)
      .sort((a,b)=> (a.role==='owner'?-1:0) - (b.role==='owner'?-1:0));
    return {
      id:g.id, name:g.name, description:g.description, town:g.town, cover:g.cover_url,
      rules:g.rules||'',
      ownerId:g.owner_id, isPrivate:g.is_private,
      kind:g.kind||'group', category:g.category,
      address:g.address, phone:g.phone, website:g.website,
      memberCount:members.length,
      isMember: !!myRow && myRow.role!=='pending',
      isPending: !!myRow && myRow.role==='pending',
      isOwner,
      isAdmin,
      isManager: isOwner || isAdmin,
      managers,
      members: members.map(toPerson)
    };
  }

  async function getGroup(groupId){
    const { data } = await sb.from('groups')
      .select(`id, name, description, town, cover_url, owner_id, is_private, kind, category, address, phone, website, rules, members:group_members ( user_id, role, profiles!user_id ( name, avatar_url, town ) )`)
      .eq('id', groupId).single();
    if(!data) return null;
    return mapGroup(data);
  }

  async function createGroup({name, description, town, isPrivate, kind, category, address, phone, website}){
    if(!_me) return {ok:false, msg:'Non connecté'};
    const row={name, description, town, owner_id:_me.id, is_private:!!isPrivate, kind:kind||'group'};
    if(category) row.category=category;
    if(address) row.address=address;
    if(phone) row.phone=phone;
    if(website) row.website=website;
    const { data, error } = await sb.from('groups').insert(row).select().single();
    if(error) return {ok:false, msg:error.message};
    await sb.from('group_members').insert({group_id:data.id, user_id:_me.id, role:'owner'});
    return {ok:true, id:data.id};
  }

  /* Rejoindre : direct si ouvert, sinon demande (role 'pending') */
  async function joinGroup(groupId){
    if(!_me) return {ok:false};
    const g=await getGroup(groupId);
    const role = g && g.isPrivate ? 'pending' : 'member';
    const { error } = await sb.from('group_members').insert({group_id:groupId, user_id:_me.id, role});
    if(error) return {ok:false, msg:error.message};
    return {ok:true, pending: role==='pending'};
  }
  async function leaveGroup(groupId){
    if(!_me) return;
    await sb.from('group_members').delete().eq('group_id',groupId).eq('user_id',_me.id);
  }

  /* Demandes d'adhésion en attente (pour l'owner) */
  async function pendingMembers(groupId){
    const { data } = await sb.from('group_members')
      .select(`user_id, role, profiles!user_id ( name, town, avatar_url )`)
      .eq('group_id', groupId).eq('role','pending');
    return (data||[]).map(m=>({
      userId:m.user_id, name:m.profiles?.name||'Membre',
      town:m.profiles?.town||'', avatar:m.profiles?.avatar_url||null
    }));
  }
  async function approveMember(groupId, userId){
    await sb.from('group_members').update({role:'member'}).eq('group_id',groupId).eq('user_id',userId);
  }
  async function rejectMember(groupId, userId){
    await sb.from('group_members').delete().eq('group_id',groupId).eq('user_id',userId);
  }

  /* Changer la couverture du groupe (owner ou admin — la RLS le contrôle).
     Accepte un Blob déjà recadré (cropImage) ou un File (recadré au besoin). */
  async function updateGroupCover(groupId, fileOrBlob){
    const isFile = fileOrBlob instanceof File;
    const url = isFile ? await uploadImage('covers', fileOrBlob, 1400, 0.78)
                       : await uploadBlob('covers', fileOrBlob);
    const { error } = await sb.from('groups').update({cover_url:url}).eq('id', groupId);
    if(error) return {ok:false, msg:error.message};
    return {ok:true, url};
  }

  /* Modifier les règles du groupe (owner ou admin) */
  async function updateGroupRules(groupId, rules){
    const { error } = await sb.from('groups').update({rules}).eq('id', groupId);
    if(error) return {ok:false, msg:error.message};
    return {ok:true};
  }

  /* Modifier des infos du groupe (owner ou admin) : description, name, etc.
     owner_id est protégé côté base par un trigger (anti-escalade). */
  async function updateGroupInfo(groupId, fields){
    const { error } = await sb.from('groups').update(fields).eq('id', groupId);
    if(error) return {ok:false, msg:error.message};
    return {ok:true};
  }

  /* Tous les membres (hors demandes en attente), avec profil + rôle.
     Pour l'écran de gestion des membres/administrateurs. */
  async function groupMembers(groupId){
    const { data } = await sb.from('group_members')
      .select(`user_id, role, profiles!user_id ( name, town, avatar_url )`)
      .eq('group_id', groupId).neq('role','pending');
    return (data||[]).map(m=>({
      userId:m.user_id, role:m.role||'member',
      name:m.profiles?.name||'Membre', town:m.profiles?.town||'',
      avatar:m.profiles?.avatar_url||null
    }));
  }

  /* Promouvoir/rétrograder un membre : role = 'admin' | 'member'
     (owner/admin uniquement ; la RLS interdit de toucher l'owner). */
  async function setMemberRole(groupId, userId, role){
    const { error } = await sb.from('group_members').update({role}).eq('group_id',groupId).eq('user_id',userId);
    if(error) return {ok:false, msg:error.message};
    return {ok:true};
  }

  /* Retirer un membre du groupe (owner/admin ; jamais l'owner). */
  async function removeMember(groupId, userId){
    const { error } = await sb.from('group_members').delete().eq('group_id',groupId).eq('user_id',userId);
    if(error) return {ok:false, msg:error.message};
    return {ok:true};
  }

  /* Publications d'un groupe */
  async function groupPosts(groupId){
    const { data } = await sb.from('posts')
      .select(`id, text, tag, image_url, images, created_at, author_id,
               author:profiles!author_id ( name, town, avatar_url ),
               video_url, link_url, link_title, link_desc, link_image, link_site, likes ( user_id, type ), poll_options, poll_votes ( user_id, choice ),
               comments ( id, text, created_at, author_id, parent_id, author:profiles!author_id ( name, avatar_url ), comment_likes ( user_id ) )`)
      .eq('group_id', groupId)
      .order('created_at', {ascending:false})
      .limit(100);
    return (data||[]).map(mapPost);
  }

  async function addGroupPost(groupId, {text, tag, image, images}){
    if(!_me) return;
    let urls=[];
    if(images && images.length) urls=await uploadImages('posts', images, 1280, 0.82);
    else if(image){ try{ urls=[await uploadImage('posts', image, 1280, 0.82)]; }catch(e){ toast('Photo trop lourde'); } }
    const { error } = await sb.from('posts').insert({
      author_id:_me.id, text, tag:tag||'Général',
      image_url:urls[0]||null, images:urls, group_id:groupId
    });
    if(error) toast(error.message);
  }

  /* Profil public de n'importe quel membre (par id) */
  async function publicProfile(userId){
    const { data } = await sb.from('profiles')
      .select('id, name, town, bio, avatar_url, cover_url, is_pro, created_at')
      .eq('id', userId).single();
    if(!data) return null;
    return {
      id:data.id, name:data.name, town:data.town, bio:data.bio||'',
      avatar:data.avatar_url, cover:data.cover_url, is_pro:data.is_pro, joined:data.created_at
    };
  }

  /* Publications d'un membre donné */
  async function userPosts(userId){
    const { data } = await sb.from('posts')
      .select(`id, text, tag, image_url, images, created_at, author_id, shared_post_id,
               author:profiles!author_id ( name, town, avatar_url ),
               shared:posts!shared_post_id ( id, text, image_url, images, created_at, author_id, author:profiles!author_id ( name, avatar_url ) ),
               video_url, link_url, link_title, link_desc, link_image, link_site, likes ( user_id, type ), poll_options, poll_votes ( user_id, choice ),
               comments ( id, text, created_at, author_id, parent_id, author:profiles!author_id ( name, avatar_url ), comment_likes ( user_id ) )`)
      .eq('author_id', userId).is('group_id', null)
      .order('created_at', {ascending:false}).limit(100);
    return (data||[]).map(mapPost);
  }

  /* Toutes les photos d'un membre (agrégées depuis ses publications) */
  async function userPhotos(userId){
    const { data } = await sb.from('posts')
      .select('images, image_url, created_at')
      .eq('author_id', userId)
      .order('created_at', {ascending:false}).limit(200);
    const photos=[];
    for(const p of (data||[])){
      let imgs = Array.isArray(p.images) ? p.images.filter(Boolean) : [];
      if(!imgs.length && p.image_url) imgs=[p.image_url];
      for(const u of imgs) photos.push(u);
    }
    return photos;
  }

  /* ============================================================
     MODÉRATION : signalement, blocage, admin
     ============================================================ */
  let _blockedIds = null;   // cache des id bloqués

  async function loadBlocked(){
    if(!_me){ _blockedIds=[]; return _blockedIds; }
    const { data } = await sb.from('blocks').select('blocked_id').eq('blocker_id', _me.id);
    _blockedIds=(data||[]).map(b=>b.blocked_id);
    return _blockedIds;
  }
  function blockedIds(){ return _blockedIds||[]; }

  async function block(userId){
    if(!_me || userId===_me.id) return;
    await sb.from('blocks').insert({blocker_id:_me.id, blocked_id:userId});
    // retirer l'amitié éventuelle
    const st=await friendStatus(userId);
    if(st.id) await sb.from('friendships').delete().eq('id', st.id);
    await loadBlocked();
  }
  async function unblock(userId){
    if(!_me) return;
    await sb.from('blocks').delete().eq('blocker_id',_me.id).eq('blocked_id',userId);
    await loadBlocked();
  }
  async function isBlocked(userId){
    if(_blockedIds===null) await loadBlocked();
    return _blockedIds.includes(userId);
  }
  async function blockedList(){
    if(!_me) return [];
    const { data } = await sb.from('blocks')
      .select(`blocked_id, profiles!blocked_id ( name, town, avatar_url )`)
      .eq('blocker_id', _me.id);
    return (data||[]).map(b=>({
      id:b.blocked_id, name:b.profiles?.name||'Membre',
      town:b.profiles?.town||'', avatar:b.profiles?.avatar_url||null
    }));
  }

  /* Signaler un post ou un utilisateur */
  async function report({postId, userId, reason, details}){
    if(!_me) return {ok:false};
    const row={ reporter_id:_me.id, reason, details:details||null,
                target_type: postId?'post':'user' };
    if(postId) row.post_id=postId;
    if(userId) row.reported_user=userId;
    const { error } = await sb.from('reports').insert(row);
    if(error) return {ok:false, msg:error.message};
    return {ok:true};
  }

  /* --- ADMIN --- */
  function isAdmin(){ return !!_me && _me.is_admin; }

  async function listReports(){
    const { data } = await sb.from('reports')
      .select(`id, reason, details, status, created_at, target_type, post_id, reported_user,
               reporter:profiles!reporter_id ( name ),
               reported:profiles!reported_user ( id, name, avatar_url ),
               post:posts!post_id ( text, author_id )`)
      .order('created_at', {ascending:false}).limit(100);
    return (data||[]).map(r=>({
      id:r.id, reason:r.reason, details:r.details, status:r.status, ts:r.created_at,
      targetType:r.target_type, postId:r.post_id, postText:r.post?.text||null,
      reporterName:r.reporter?.name||'?',
      reportedId:r.reported?.id||r.reported_user, reportedName:r.reported?.name||null
    }));
  }
  async function resolveReport(id, status){
    await sb.from('reports').update({status}).eq('id', id);
  }
  async function adminDeletePost(postId){
    await sb.from('posts').delete().eq('id', postId);
  }
  async function banUser(userId){
    await sb.from('profiles').update({is_banned:true}).eq('id', userId);
  }
  async function unbanUser(userId){
    await sb.from('profiles').update({is_banned:false}).eq('id', userId);
  }

  /* ============================================================
     SUGGESTIONS D'AMIS (amis communs prioritaires, façon FB)
     ============================================================ */
  async function friendSuggestions(limit=8){
    if(!_me) return [];
    // Relations existantes (amis + en attente) pour exclure
    const { data:rel } = await sb.from('friendships')
      .select('requester_id, addressee_id')
      .or(`requester_id.eq.${_me.id},addressee_id.eq.${_me.id}`);
    const related = new Set([_me.id]);
    (rel||[]).forEach(f=>{ related.add(f.requester_id); related.add(f.addressee_id); });
    await loadBlocked(); const blocked=new Set(blockedIds());

    let out=[];
    // 1) Amis communs (fonction SQL)
    try{
      const { data } = await sb.rpc('friend_suggestions', { lim: limit });
      const mutualMap={}; (data||[]).forEach(r=>{ mutualMap[r.user_id]=r.mutual; });
      const ids=(data||[]).map(r=>r.user_id).filter(id=>!related.has(id) && !blocked.has(id));
      if(ids.length){
        const { data:profs } = await sb.from('profiles').select('id,name,town,avatar_url').in('id', ids);
        out=(profs||[]).map(p=>({id:p.id, name:p.name, town:p.town||'', avatar:p.avatar_url||null, mutual:mutualMap[p.id]||0}))
              .sort((a,b)=>b.mutual-a.mutual);
      }
    }catch(e){ /* fonction absente -> on passe au repli */ }

    // 2) Repli : membres récents si pas assez de suggestions
    if(out.length<limit){
      const have=new Set(out.map(o=>o.id));
      const { data:recent } = await sb.from('profiles')
        .select('id,name,town,avatar_url').order('created_at',{ascending:false}).limit(50);
      for(const p of (recent||[])){
        if(out.length>=limit) break;
        if(related.has(p.id)||blocked.has(p.id)||have.has(p.id)) continue;
        out.push({id:p.id, name:p.name, town:p.town||'', avatar:p.avatar_url||null, mutual:0});
        have.add(p.id);
      }
    }
    return out.slice(0, limit);
  }

  /* ============================================================
     MARKETPLACE / PETITES ANNONCES
     ============================================================ */
  function mapListing(l){
    const imgs = Array.isArray(l.images) ? l.images.filter(Boolean) : [];
    return {
      id:l.id, title:l.title, description:l.description||'',
      price:(l.price===null||l.price===undefined)?null:Number(l.price),
      category:l.category||'Divers', town:l.town||'', images:imgs,
      status:l.status||'active', ts:l.created_at,
      sellerId:l.seller_id, sellerName:l.seller?.name||'Membre',
      sellerAvatar:l.seller?.avatar_url||null, sellerTown:l.seller?.town||'',
      mine: l.seller_id===_me?.id
    };
  }
  async function listListings({search='', category='', town=''}={}){
    let q=sb.from('listings')
      .select(`id, title, description, price, category, town, images, status, created_at, seller_id, seller:profiles!seller_id ( name, avatar_url, town )`)
      .order('created_at',{ascending:false}).limit(120);
    if(category) q=q.eq('category', category);
    if(town)     q=q.eq('town', town);
    if(search)   q=q.ilike('title', `%${search}%`);
    const { data } = await q;
    return (data||[]).map(mapListing);
  }
  async function getListing(id){
    const { data } = await sb.from('listings')
      .select(`id, title, description, price, category, town, images, status, created_at, seller_id, seller:profiles!seller_id ( name, avatar_url, town )`)
      .eq('id', id).single();
    return data ? mapListing(data) : null;
  }
  async function createListing({title, description, price, category, town, images}){
    if(!_me) return {ok:false, msg:'Non connecté'};
    let urls=[];
    if(images && images.length) urls=await uploadImages('posts', images, 1280, 0.82);
    const row={
      seller_id:_me.id, title, description:description||null,
      category:category||'Divers', town:town||null, images:urls,
      price:(price===''||price===null||price===undefined)?null:Number(price)
    };
    const { data, error } = await sb.from('listings').insert(row).select().single();
    if(error) return {ok:false, msg:error.message};
    return {ok:true, id:data.id};
  }
  async function markListingSold(id, sold=true){
    const { error } = await sb.from('listings').update({status:sold?'sold':'active'}).eq('id', id);
    return error ? {ok:false, msg:error.message} : {ok:true};
  }
  async function deleteListing(id){
    const { error } = await sb.from('listings').delete().eq('id', id);
    return error ? {ok:false, msg:error.message} : {ok:true};
  }

  /* ============================================================
     AVIS & NOTES SUR LES PAGES
     ============================================================ */
  async function pageReviews(pageId){
    const { data } = await sb.from('page_reviews')
      .select(`id, rating, text, created_at, author_id, author:profiles!author_id ( name, avatar_url )`)
      .eq('page_id', pageId).order('created_at',{ascending:false});
    const list=(data||[]).map(r=>({
      id:r.id, userId:r.author_id, rating:r.rating, text:r.text||'', ts:r.created_at,
      author:r.author?.name||'Membre', avatar:r.author?.avatar_url||null
    }));
    const count=list.length;
    const avg=count ? (list.reduce((s,r)=>s+r.rating,0)/count) : 0;
    const mine=list.find(r=>r.userId===_me?.id)||null;
    return { count, avg, mine, list };
  }
  async function saveReview(pageId, {rating, text}){
    if(!_me) return {ok:false, msg:'Non connecté'};
    if(!(rating>=1 && rating<=5)) return {ok:false, msg:'Note invalide'};
    const { error } = await sb.from('page_reviews')
      .upsert({page_id:pageId, author_id:_me.id, rating, text:text||null}, {onConflict:'page_id,author_id'});
    return error ? {ok:false, msg:error.message} : {ok:true};
  }
  async function deleteMyReview(pageId){
    if(!_me) return {ok:false};
    const { error } = await sb.from('page_reviews').delete().eq('page_id',pageId).eq('author_id',_me.id);
    return error ? {ok:false, msg:error.message} : {ok:true};
  }

  /* ============================================================
     STORIES ÉPHÉMÈRES (24 h)
     ============================================================ */
  async function listStories(){
    const { data, error } = await sb.from('stories')
      .select('id, media_url, media_type, text, created_at, author_id, author:profiles!author_id ( name, avatar_url )')
      .gt('expires_at', new Date().toISOString())
      .order('created_at', {ascending:true});
    if(error){ console.error(error); return []; }
    let seen=new Set();
    if(_me){
      const { data:v } = await sb.from('story_views').select('story_id').eq('user_id', _me.id);
      (v||[]).forEach(r=>seen.add(r.story_id));
    }
    const byAuthor=new Map();
    (data||[]).forEach(s=>{
      if(!byAuthor.has(s.author_id)) byAuthor.set(s.author_id, {
        authorId:s.author_id, name:s.author?.name||'Membre', avatar:s.author?.avatar_url||null,
        items:[], hasUnseen:false, mine:s.author_id===_me?.id
      });
      const g=byAuthor.get(s.author_id);
      g.items.push({id:s.id, url:s.media_url, type:s.media_type||'image', text:s.text||'', ts:s.created_at, seen:seen.has(s.id)});
      if(!seen.has(s.id)) g.hasUnseen=true;
    });
    const arr=[...byAuthor.values()];
    arr.sort((a,b)=> (b.mine?1:0)-(a.mine?1:0) || (b.hasUnseen?1:0)-(a.hasUnseen?1:0));
    return arr;
  }
  async function addStory({file, text}){
    if(!_me || !file) return {ok:false};
    const isVideo=(file.type||'').startsWith('video/');
    let url;
    try{ url = isVideo ? await uploadVideo(file) : await uploadImage('posts', file, 1280, 0.85); }
    catch(e){ return {ok:false, msg:'Média trop lourd ou refusé'}; }
    const { error } = await sb.from('stories')
      .insert({author_id:_me.id, media_url:url, media_type:isVideo?'video':'image', text:text||null});
    return error ? {ok:false, msg:error.message} : {ok:true};
  }
  async function markStoryViewed(storyId){
    if(!_me) return;
    await sb.from('story_views').upsert({story_id:storyId, user_id:_me.id}, {onConflict:'story_id,user_id'});
  }
  async function storyViewCount(storyId){
    const { count } = await sb.from('story_views').select('user_id',{count:'exact',head:true}).eq('story_id', storyId);
    return count||0;
  }
  async function deleteStory(id){
    if(!_me) return;
    await sb.from('stories').delete().eq('id', id).eq('author_id', _me.id);
  }

  /* ============================================================
     PUBLICITÉS (régie — affichage dans le fil, gestion admin)
     ============================================================ */
  /* Quelle pub afficher (membre) : rotation aléatoire parmi les
     pubs actives, dans leurs dates, sous le plafond mensuel.
     device = 'pc' | 'mobile' (sert l'image du bon format). */
  function adDevice(){
    return (window.matchMedia && window.matchMedia('(max-width:900px)').matches) ? 'mobile' : 'pc';
  }
  async function activeAds(device){
    const { data, error } = await sb.rpc('active_ads', { device: device || adDevice() });
    if(error){ console.error(error); return []; }
    return data || [];
  }
  /* Tire une pub au hasard pour l'écran courant et compte l'affichage. */
  async function pickAd(device){
    const dev = device || adDevice();
    const list = await activeAds(dev);
    if(!list.length) return null;
    const ad = list[Math.floor(Math.random()*list.length)];
    adImpression(ad.id);   // compte sans bloquer l'affichage
    return ad;
  }
  async function adImpression(id){
    try{ await sb.rpc('ad_impression', { ad_id: id }); }catch(e){ /* silencieux */ }
  }
  async function adClick(id){
    try{ await sb.rpc('ad_click', { ad_id: id }); }catch(e){ /* silencieux */ }
  }

  /* --- Régie (admin) --- */
  async function listAds(){
    const { data, error } = await sb.from('ads').select('*')
      .order('sort_order', {ascending:true}).order('created_at', {ascending:true});
    if(error){ console.error(error); return []; }
    return (data||[]).map(a=>{
      const mk = a.month_key;
      // affichages du mois en cours (0 si le compteur date d'un autre mois)
      const now = new Date();
      const curKey = now.getFullYear()+'-'+String(now.getMonth()+1).padStart(2,'0');
      const cur = mk===curKey;
      return { ...a,
        shownThisMonth: cur ? (a.impressions||0) : 0,
        clicksThisMonth: cur ? (a.clicks||0) : 0 };
    });
  }
  async function createAd(fields){
    const { data, error } = await sb.from('ads').insert(fields).select().single();
    return error ? {ok:false, msg:error.message} : {ok:true, id:data.id};
  }
  async function updateAd(id, fields){
    const { error } = await sb.from('ads').update(fields).eq('id', id);
    return error ? {ok:false, msg:error.message} : {ok:true};
  }
  async function deleteAd(id){
    const { error } = await sb.from('ads').delete().eq('id', id);
    return error ? {ok:false, msg:error.message} : {ok:true};
  }
  /* Réordonne d'après un tableau d'ids (drag & drop) : sort_order = index. */
  async function reorderAds(ids){
    for(let i=0;i<ids.length;i++){
      await sb.from('ads').update({sort_order:i}).eq('id', ids[i]);
    }
    return {ok:true};
  }

  /* ============================================================
     API publique
     ============================================================ */
  return {
    sb, loadMe, requireAuth, user, toast, avatarHTML,
    colorFor, initials, esc, timeAgo, uploadImage, uploadBlob, uploadVideo, cropImage, fileToBlob,
    mentionHTML, attachMentions, tokenizeMentions, COMMUNES, fillCommuneSelect,
    register, login, logout, updateProfile, updateEmail, updatePassword, deleteAccount, setEmailNotifications, setEmailMode,
    savePushSubscription, deletePushSubscription,
    posts, getPost, addPost, sharePost, deletePost, editPost, editComment, toggleLike, isLiked, reactPost, REACTIONS, reactionMeta, addComment, toggleCommentLike,
    votePoll, removePollVote,
    events, getEvent, toggleGoing, isGoing, setEventRsvp, eventComments, addEventComment, deleteEventComment, createEvent, updateEvent, updateEventCover, deleteEvent,
    notifications, unreadCount, markAllRead, notifText, subscribeNotifications,
    follow, unfollow, isFollowing, followCounts,
    members, openConversationWith, contactSeller, conversations, messagesOf, sendMessage, subscribeMessages,
    createGroupConversation, conversationInfo, addConversationMembers, leaveConversation, renameConversation,
    searchPosts,
    friendStatus, sendFriendRequest, acceptFriend, removeFriend, pendingRequests, friends, friendCount, areFriends, friendSuggestions,
    listGroups, getGroup, createGroup, joinGroup, leaveGroup, groupPosts, addGroupPost,
    uploadImages, pendingMembers, approveMember, rejectMember, updateGroupCover,
    updateGroupRules, updateGroupInfo, groupMembers, setMemberRole, removeMember,
    publicProfile, userPosts, userPhotos,
    listListings, getListing, createListing, markListingSold, deleteListing,
    pageReviews, saveReview, deleteMyReview,
    listStories, addStory, markStoryViewed, storyViewCount, deleteStory,
    activeAds, pickAd, adImpression, adClick, listAds, createAd, updateAd, deleteAd, reorderAds,
    report, block, unblock, isBlocked, blockedList, loadBlocked, blockedIds,
    isAdmin, listReports, resolveReport, adminDeletePost, banUser, unbanUser
  };
})();
