/* Modale de signalement + helpers de blocage, partagés entre pages.
   À inclure après app.supabase.js. Expose window.Mod. */
(function(){
  const REASONS=[
    ['spam','Spam ou publicité'],
    ['harcelement','Harcèlement'],
    ['faux','Faux compte / usurpation'],
    ['illegal','Contenu illégal'],
    ['inapproprie','Contenu inapproprié']
  ];

  function ensureModal(){
    if(document.getElementById('modReportBg')) return;
    const bg=document.createElement('div');
    bg.className='modal-bg'; bg.id='modReportBg';
    bg.innerHTML=`
      <div class="modal">
        <div class="modal-head"><h3 id="modReportTitle">Signaler</h3><button class="x" id="modReportClose">&times;</button></div>
        <div class="modal-body">
          <p style="color:var(--ink-soft);font-size:.9rem;margin-bottom:10px">Pourquoi signales-tu ce contenu ? Notre équipe examinera ton signalement.</p>
          <div class="report-reasons" id="modReasons">
            ${REASONS.map((r,i)=>`<label><input type="radio" name="modReason" value="${r[0]}" ${i===0?'checked':''}> ${r[1]}</label>`).join('')}
          </div>
          <div class="field" style="margin-top:10px"><label for="modDetails">Détails (optionnel)</label><textarea id="modDetails" maxlength="300" placeholder="Précise si besoin…"></textarea></div>
        </div>
        <div class="modal-foot">
          <button class="btn btn-ghost btn-sm" id="modReportCancel">Annuler</button>
          <button class="btn btn-primary btn-sm" id="modReportSend">Envoyer le signalement</button>
        </div>
      </div>`;
    document.body.appendChild(bg);
    const close=()=>bg.classList.remove('open');
    bg.querySelector('#modReportClose').addEventListener('click',close);
    bg.querySelector('#modReportCancel').addEventListener('click',close);
    bg.addEventListener('click',e=>{ if(e.target===bg) close(); });
  }

  /* Ouvre la modale. target = {postId} ou {userId} */
  function openReport(target){
    ensureModal();
    const bg=document.getElementById('modReportBg');
    document.getElementById('modReportTitle').textContent = target.userId ? 'Signaler ce membre' : 'Signaler cette publication';
    document.getElementById('modDetails').value='';
    const sendBtn=document.getElementById('modReportSend');
    const fresh=sendBtn.cloneNode(true);   // retirer les anciens listeners
    sendBtn.parentNode.replaceChild(fresh, sendBtn);
    fresh.addEventListener('click',async()=>{
      const reason=document.querySelector('input[name="modReason"]:checked').value;
      const details=document.getElementById('modDetails').value.trim();
      fresh.disabled=true;
      const r=await JP.report({postId:target.postId, userId:target.userId, reason, details});
      fresh.disabled=false;
      if(r.ok){ JP.toast('Signalement envoyé. Merci !'); bg.classList.remove('open'); }
      else JP.toast(r.msg||'Échec du signalement');
    });
    bg.classList.add('open');
  }

  async function blockUser(userId, name){
    if(!confirm(`Bloquer ${name||'ce membre'} ? Tu ne verras plus son contenu et il ne pourra plus t'écrire.`)) return false;
    await JP.block(userId);
    JP.toast('Membre bloqué');
    return true;
  }

  window.Mod={ openReport, blockUser };
})();
