/* ============================================================
   BePotes — Appels audio/vidéo (WebRTC pair-à-pair)
   - Signalisation : Supabase Realtime broadcast (canal « inbox » par
     utilisateur : calls:<userId>). Aucune table, aucun message stocké.
   - Média : P2P chiffré (DTLS-SRTP). STUN public Google (gratuit).
   - À inclure après app.supabase.js sur les pages connectées : reçoit
     les appels entrants partout. JPCall.start(...) lance un appel.
   ⚠ STUN seul : marche derrière la plupart des box. Réseaux très
     restrictifs (NAT symétrique, certains 4G/entreprise) => prévoir un
     TURN plus tard (voir guide). Le 1-à-1 reste amis-only (UI).
   ============================================================ */
window.JPCall = (function () {
  const ICE = { iceServers: [
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' }
  ] };
  const sb = (window.JP && JP.sb) ? JP.sb : null;

  let me = null, inbox = null;
  let pc = null, localStream = null, sendCh = null;
  let cur = null;            // { callId, peerId, peerName, peerAvatar, video, role }
  let pendingOffer = null;   // offre reçue en attente d'acceptation
  let pendingIce = [];       // ICE reçus avant setRemoteDescription
  let ui = null, ringTimer = null, durTimer = null, startedAt = 0;

  /* ---------------- UI ---------------- */
  function ensureUI() {
    if (ui) return ui;
    const ov = document.createElement('div');
    ov.className = 'call-ov';
    ov.id = 'jp-call';
    ov.innerHTML =
      '<div class="call-stage">' +
        '<video class="call-remote" id="jpcRemote" autoplay playsinline></video>' +
        '<video class="call-local" id="jpcLocal" autoplay playsinline muted></video>' +
        '<div class="call-info" id="jpcInfo">' +
          '<div class="call-av" id="jpcAv"></div>' +
          '<div class="call-name" id="jpcName"></div>' +
          '<div class="call-status" id="jpcStatus"></div>' +
        '</div>' +
        '<div class="call-incoming" id="jpcIncoming" style="display:none">' +
          '<button class="accept" id="jpcAccept">Accepter</button>' +
          '<button class="decline" id="jpcDecline">Refuser</button>' +
        '</div>' +
        '<div class="call-ctrls" id="jpcCtrls">' +
          '<button id="jpcMic" title="Micro" aria-label="Micro">🎤</button>' +
          '<button id="jpcCam" title="Caméra" aria-label="Caméra">🎥</button>' +
          '<button id="jpcHang" class="hang" title="Raccrocher" aria-label="Raccrocher">📵</button>' +
        '</div>' +
      '</div>';
    document.body.appendChild(ov);
    ui = ov;
    ov.querySelector('#jpcHang').addEventListener('click', () => { if (cur) sendCur({ kind: 'hangup', callId: cur.callId }); endCall('Appel terminé'); });
    ov.querySelector('#jpcAccept').addEventListener('click', acceptIncoming);
    ov.querySelector('#jpcDecline').addEventListener('click', () => { if (cur) sendCur({ kind: 'decline', callId: cur.callId }); endCall('Appel refusé'); });
    ov.querySelector('#jpcMic').addEventListener('click', toggleMic);
    ov.querySelector('#jpcCam').addEventListener('click', toggleCam);
    return ov;
  }
  function paintHeader() {
    ensureUI();
    ui.querySelector('#jpcAv').innerHTML = (window.JP ? JP.avatarHTML(cur.peerName, cur.peerAvatar, 'av') : '');
    ui.querySelector('#jpcName').textContent = cur.peerName || 'Jurapote';
    ui.classList.toggle('video', !!cur.video);
  }
  function setStatus(t) { if (ui) ui.querySelector('#jpcStatus').textContent = t; }
  function showState(state) {
    ensureUI();
    ui.classList.add('open');
    const inc = ui.querySelector('#jpcIncoming'), ctr = ui.querySelector('#jpcCtrls');
    if (state === 'incoming') { inc.style.display = 'flex'; ctr.style.display = 'none'; }
    else { inc.style.display = 'none'; ctr.style.display = 'flex'; }
  }
  function startTimer() {
    startedAt = (window.performance && performance.now) ? performance.now() : 0;
    let secs = 0;
    durTimer = setInterval(() => { secs++; const m = Math.floor(secs / 60), s = secs % 60; setStatus(m + ':' + String(s).padStart(2, '0')); }, 1000);
  }

  /* ---------------- Signalisation ---------------- */
  // Envoie un message à l'inbox du destinataire (canal calls:<toId>).
  function signal(toId, payload) {
    if (!sb || !toId) return;
    payload.from = me.id; payload.fromName = me.name; payload.fromAvatar = me.avatar || null;
    const ch = sb.channel('calls:' + toId);
    ch.subscribe(st => {
      if (st === 'SUBSCRIBED') {
        ch.send({ type: 'broadcast', event: 'signal', payload });
        setTimeout(() => { try { sb.removeChannel(ch); } catch (e) {} }, 1200);
      }
    });
  }
  // Canal persistant vers le pair pour la durée de l'appel (ICE nombreux).
  function openSendCh(peerId) {
    closeSendCh();
    sendCh = sb.channel('calls:' + peerId);
    sendCh.subscribe();
  }
  function sendCur(payload) {
    if (!sendCh) { signal(cur && cur.peerId, payload); return; }
    payload.from = me.id; payload.fromName = me.name; payload.fromAvatar = me.avatar || null;
    try { sendCh.send({ type: 'broadcast', event: 'signal', payload }); } catch (e) {}
  }
  function closeSendCh() { if (sendCh) { try { sb.removeChannel(sendCh); } catch (e) {} sendCh = null; } }

  function initInbox() {
    if (!sb || inbox) return;
    inbox = sb.channel('calls:' + me.id, { config: { broadcast: { self: false } } })
      .on('broadcast', { event: 'signal' }, ({ payload }) => route(payload))
      .subscribe();
  }

  function route(p) {
    if (!p || !p.kind) return;
    if (p.kind === 'ring') return onRing(p);
    if (!cur || p.callId !== cur.callId) return;       // ignore ce qui ne concerne pas l'appel courant
    if (p.kind === 'accept') return onAccept(p);
    if (p.kind === 'ice')    return onIce(p);
    if (p.kind === 'decline'){ return endCall('Appel refusé'); }
    if (p.kind === 'busy')   { return endCall('Occupé'); }
    if (p.kind === 'hangup') { return endCall('Appel terminé'); }
  }

  /* ---------------- PeerConnection ---------------- */
  function newPC() {
    pc = new RTCPeerConnection(ICE);
    pc.onicecandidate = e => { if (e.candidate) sendCur({ kind: 'ice', callId: cur.callId, candidate: e.candidate }); };
    pc.ontrack = e => {
      const rv = ui.querySelector('#jpcRemote');
      if (rv.srcObject !== e.streams[0]) rv.srcObject = e.streams[0];
      ui.classList.add('connected');
    };
    pc.onconnectionstatechange = () => {
      if (!pc) return;
      if (pc.connectionState === 'connected') { if (cur) cur.connected = true; setStatus('Connecté'); if (!durTimer) startTimer(); }
      if (pc.connectionState === 'failed' || pc.connectionState === 'disconnected') endCall('Connexion perdue');
    };
    (localStream.getTracks() || []).forEach(t => pc.addTrack(t, localStream));
  }
  async function getMedia(video) {
    localStream = await navigator.mediaDevices.getUserMedia({ audio: true, video: video ? { facingMode: 'user' } : false });
    ui.querySelector('#jpcLocal').srcObject = localStream;
    ui.querySelector('#jpcCam').style.display = video ? '' : 'none';
  }
  async function drainIce() { for (const c of pendingIce) { try { await pc.addIceCandidate(c); } catch (e) {} } pendingIce = []; }

  /* ---------------- Appel sortant ---------------- */
  async function start(peerId, peerName, peerAvatar, video) {
    if (!sb) { if (window.JP) JP.toast('Appels indisponibles'); return; }
    if (cur) { if (window.JP) JP.toast('Un appel est déjà en cours'); return; }
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) { if (window.JP) JP.toast('Ton navigateur ne gère pas les appels', { error: true }); return; }
    const callId = (window.crypto && crypto.randomUUID) ? crypto.randomUUID() : ('c' + Date.now() + Math.round(Math.random() * 1e6));
    cur = { callId, peerId, peerName, peerAvatar, video: !!video, role: 'caller' };
    paintHeader(); showState('calling'); setStatus('Appel en cours…');
    try { await getMedia(video); } catch (e) { endCall(); if (window.JP) JP.toast('Accès micro/caméra refusé', { error: true }); return; }
    openSendCh(peerId); newPC();
    try {
      const offer = await pc.createOffer({ offerToReceiveAudio: true, offerToReceiveVideo: !!video });
      await pc.setLocalDescription(offer);
      sendCur({ kind: 'ring', callId, video: !!video, sdp: offer });
      cur.rang = true;   // l'appel a sonné -> s'il n'aboutit pas, ce sera un « appel manqué »
    } catch (e) { endCall(); return; }
    ringTimer = setTimeout(() => { if (cur && cur.role === 'caller' && (!pc || pc.connectionState !== 'connected')) { sendCur({ kind: 'hangup', callId }); endCall('Pas de réponse'); } }, 35000);
  }

  /* ---------------- Appel entrant ---------------- */
  function onRing(p) {
    if (cur) { signal(p.from, { kind: 'busy', callId: p.callId }); return; }   // déjà occupé
    cur = { callId: p.callId, peerId: p.from, peerName: p.fromName, peerAvatar: p.fromAvatar, video: !!p.video, role: 'callee' };
    pendingOffer = p.sdp;
    paintHeader(); showState('incoming'); setStatus(p.video ? 'Appel vidéo entrant…' : 'Appel entrant…');
    try { if (navigator.vibrate) navigator.vibrate([400, 200, 400]); } catch (e) {}
    ringTimer = setTimeout(() => { if (cur && cur.role === 'callee' && !pc) { signal(cur.peerId, { kind: 'decline', callId: cur.callId }); endCall('Appel manqué'); } }, 35000);
  }
  async function acceptIncoming() {
    if (!cur || cur.role !== 'callee' || !pendingOffer) return;
    showState('in'); setStatus('Connexion…');
    try { await getMedia(cur.video); } catch (e) { signal(cur.peerId, { kind: 'decline', callId: cur.callId }); endCall(); if (window.JP) JP.toast('Accès micro/caméra refusé', { error: true }); return; }
    openSendCh(cur.peerId); newPC();
    try {
      await pc.setRemoteDescription(new RTCSessionDescription(pendingOffer));
      await drainIce();
      const answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      sendCur({ kind: 'accept', callId: cur.callId, sdp: answer });
    } catch (e) { endCall(); return; }
    pendingOffer = null;
  }
  async function onAccept(p) {
    if (!pc) return;
    showState('in'); setStatus('Connexion…');
    try { await pc.setRemoteDescription(new RTCSessionDescription(p.sdp)); await drainIce(); } catch (e) {}
  }
  async function onIce(p) {
    if (!p.candidate) return;
    if (pc && pc.remoteDescription && pc.remoteDescription.type) { try { await pc.addIceCandidate(p.candidate); } catch (e) {} }
    else pendingIce.push(p.candidate);
  }

  /* ---------------- Contrôles ---------------- */
  function toggleMic() {
    if (!localStream) return;
    const t = localStream.getAudioTracks()[0]; if (!t) return;
    t.enabled = !t.enabled;
    const b = ui.querySelector('#jpcMic'); b.textContent = t.enabled ? '🎤' : '🔇'; b.classList.toggle('off', !t.enabled);
  }
  function toggleCam() {
    if (!localStream) return;
    const t = localStream.getVideoTracks()[0]; if (!t) return;
    t.enabled = !t.enabled;
    const b = ui.querySelector('#jpcCam'); b.classList.toggle('off', !t.enabled);
  }

  /* ---------------- Fin ---------------- */
  function endCall(msg) {
    if (!cur && !pc && !localStream) return;   // déjà terminé : évite un 2e toast (« Connexion perdue ») après un raccrochage propre
    const c = cur;   // capturé avant remise à zéro (pour journaliser un appel manqué)
    if (ringTimer) { clearTimeout(ringTimer); ringTimer = null; }
    if (durTimer) { clearInterval(durTimer); durTimer = null; }
    // On détache le canal d'envoi mais on le ferme un peu plus tard : laisse partir le dernier « hangup ».
    if (sendCh) { const ch = sendCh; sendCh = null; setTimeout(() => { try { sb.removeChannel(ch); } catch (e) {} }, 500); }
    if (pc) { try { pc.ontrack = pc.onicecandidate = pc.onconnectionstatechange = null; pc.close(); } catch (e) {} pc = null; }
    if (localStream) { localStream.getTracks().forEach(t => { try { t.stop(); } catch (e) {} }); localStream = null; }
    pendingOffer = null; pendingIce = []; cur = null;
    if (ui) {
      ui.classList.remove('open', 'video', 'connected');
      const rv = ui.querySelector('#jpcRemote'), lv = ui.querySelector('#jpcLocal');
      if (rv) rv.srcObject = null; if (lv) lv.srcObject = null;
    }
    if (msg && window.JP) JP.toast(msg);
    // Appel non abouti côté appelant (sans réponse / refusé / annulé pendant la sonnerie)
    // -> message « Appel manqué » dans la conversation + notification pour le destinataire.
    if (c && c.role === 'caller' && c.rang && !c.connected && window.JP && JP.logMissedCall) {
      JP.logMissedCall(c.peerId, c.video);
    }
  }

  /* ---------------- Init ---------------- */
  (async function () {
    if (!sb) return;
    if (!window.JP || !JP.user) return;
    if (!JP.user()) { if (JP.loadMe) { try { await JP.loadMe(); } catch (e) {} } }
    const u = JP.user && JP.user();
    if (!u) return;
    me = u;
    initInbox();
  })();

  return { start, end: endCall, active: () => !!cur };
})();

