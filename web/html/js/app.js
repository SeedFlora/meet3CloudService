'use strict';

// Net Web Lab frontend: tanpa framework dan tanpa build step.
// Semua URL relatif (api/health, student.json), jadi halaman tetap benar
// dibuka dari http://localhost:8080, https://localhost:8443, maupun URL Codespaces.

(() => {
  const $ = (id) => document.getElementById(id);

  // Subnet jaringan Docker di compose.yaml, untuk memberi nama pada alamat IP.
  const NETWORKS = [
    ['172.28.10.', 'edge'],
    ['172.28.20.', 'app'],
    ['172.28.30.', 'data'],
  ];
  const netName = (ip) => (NETWORKS.find(([prefix]) => String(ip).startsWith(prefix)) || [])[1];

  const timeFmt = new Intl.DateTimeFormat('id-ID', { dateStyle: 'medium', timeStyle: 'short' });
  const clockFmt = new Intl.DateTimeFormat('id-ID', { timeStyle: 'medium' });
  const STATION = { client: '12.5%', web: '37.5%', api: '62.5%', db: '87.5%' };

  async function fetchJson(url, options = {}) {
    const started = performance.now();
    const res = await fetch(url, { cache: 'no-store', headers: { Accept: 'application/json' }, ...options });
    const ms = Math.round(performance.now() - started);
    const type = res.headers.get('content-type') || '';
    const body = type.includes('application/json') ? await res.json().catch(() => null) : null;
    if (!body) await res.text().catch(() => '');
    return { res, body, ms };
  }

  function setText(id, text) {
    $(id).textContent = text;
  }

  function setHop(name, state, label) {
    $(`hop-${name}`).dataset.state = state;
    setText(`state-${name}`, label);
  }

  // ---------- Browser (klien) ----------

  function describeClient() {
    setText('f-origin', location.host);
    const nav = performance.getEntriesByType('navigation')[0];
    const hop = nav && nav.nextHopProtocol ? nav.nextHopProtocol : '';
    const scheme = location.protocol.replace(':', '');
    setText('f-proto', hop ? `${scheme}, ${hop}` : scheme);
  }

  // ---------- Status tiga tier (/api/health) ----------

  function travel(stop) {
    const map = $('map');
    map.style.setProperty('--stop', STATION[stop]);
    map.classList.remove('travel');
    void map.offsetWidth; // mulai ulang animasi
    map.classList.add('travel');
  }

  async function checkTiers() {
    const button = $('recheck');
    button.disabled = true;
    ['web', 'api', 'db'].forEach((t) => setHop(t, 'wait', 'memeriksa'));

    let stop = 'client';
    try {
      const { res, body, ms } = await fetchJson('api/health');
      // Ada jawaban HTTP = nginx hidup (walaupun statusnya 502 dari nginx).
      setHop('web', 'ok', 'berjalan');
      setText('f-web-server', res.headers.get('server') || 'nginx');
      stop = 'web';

      if (body && body.service === 'api') {
        setHop('api', 'ok', 'berjalan');
        setText('f-api-host', body.hostname || '-');
        setText('f-api-ms', `${ms} ms (${body.node || 'Node.js'})`);
        stop = 'api';
        if (body.db === 'up') {
          setHop('db', 'ok', 'berjalan');
          setText('f-db-version', body.db_version || 'PostgreSQL');
          setText('f-db-notes', `${body.notes} catatan`);
          stop = 'db';
        } else {
          setHop('db', 'bad', 'tidak terjangkau');
          setText('f-db-version', body.error || '-');
          setText('f-db-notes', '-');
        }
      } else {
        setHop('api', 'bad', `nginx menjawab ${res.status}`);
        setHop('db', 'wait', 'tidak diketahui');
        setText('f-api-host', '-');
        setText('f-api-ms', '-');
      }
    } catch (err) {
      setHop('web', 'bad', 'tidak terjangkau');
      setHop('api', 'wait', 'tidak diketahui');
      setHop('db', 'wait', 'tidak diketahui');
    } finally {
      button.disabled = false;
      setText('checked-at', `Diperiksa pukul ${clockFmt.format(new Date())}`);
      travel(stop);
    }
  }

  // ---------- Dilihat dari server (/api/whoami) ----------

  function withNet(ip) {
    const name = netName(ip);
    return name ? `${ip} (${name})` : ip;
  }

  // Alamat x.x.x.1 di subnet lab = gateway jaringan Docker. Request dari browser di
  // host masuk lewat port yang dipublish, sehingga nginx melihat alamat gateway ini.
  function setClientIp(id, value) {
    const cell = $(id);
    if (!value) {
      cell.textContent = '(tidak ada)';
      return;
    }
    cell.textContent = value;
    const first = value.split(',')[0].trim();
    if (/^172\.28\.(10|20|30)\.1$/.test(first)) {
      const note = document.createElement('small');
      note.textContent = ' gateway Docker: request masuk dari host lewat port yang dipublish';
      cell.append(note);
    }
  }

  async function loadWhoami() {
    try {
      const { body } = await fetchJson('api/whoami');
      if (!body) throw new Error('bukan JSON');
      const h = body.headers || {};
      setText('w-host', body.hostname || '-');
      setText('w-ips', (body.addresses || []).map((a) => withNet(a.address)).join(', ') || '-');

      const remote = $('w-remote');
      remote.textContent = withNet(body.remoteAddress || '-');
      if (body.viaProxy) {
        const note = document.createElement('small');
        note.textContent = ' nginx, bukan browser Anda';
        remote.append(note);
      }
      setClientIp('w-xff', h['x-forwarded-for']);
      setText('w-xrip', h['x-real-ip'] || '(tidak ada)');
      setText('w-proto', h['x-forwarded-proto'] || '(tidak ada)');
      setText('w-hosthdr', h.host || '-');
      setText('w-ua', h['user-agent'] || '-');

      // Port container yang menerima request, dilihat dari sisi nginx ($scheme).
      // (Di Codespaces browser memakai HTTPS ke GitHub, tetapi nginx tetap menerima HTTP.)
      setText('link-web-port', h['x-forwarded-proto'] === 'https' ? 'host → 443' : 'host → 80');

      const conn = $('conn');
      if (h['x-forwarded-proto'] === 'https') {
        conn.dataset.state = 'tls';
        conn.textContent = 'nginx menerima HTTPS (TLS)';
      } else {
        conn.dataset.state = 'plain';
        conn.textContent = 'nginx menerima HTTP, tanpa enkripsi';
      }
    } catch (err) {
      setText('w-explain', 'Data /api/whoami tidak bisa diambil. Cek: docker compose logs web api');
      $('conn').dataset.state = 'wait';
      setText('conn', 'Koneksi ke API gagal');
    }
  }

  // ---------- Catatan (/api/notes) ----------

  function renderNotes(notes, freshId) {
    const list = $('notes');
    list.replaceChildren();
    notes.slice(0, 8).forEach((n) => {
      const li = document.createElement('li');
      if (n.id === freshId) li.className = 'fresh';
      const id = document.createElement('span');
      id.className = 'n-id';
      id.textContent = `#${n.id}`;
      const text = document.createElement('span');
      text.className = 'n-text';
      text.textContent = n.text;                 // textContent: aman dari HTML/skrip sisipan
      const time = document.createElement('time');
      time.className = 'n-time';
      time.dateTime = n.created_at;
      time.textContent = timeFmt.format(new Date(n.created_at));
      li.append(id, text, time);
      list.append(li);
    });
    $('notes-empty').hidden = notes.length > 0;
  }

  async function loadNotes(freshId) {
    try {
      const { res, body } = await fetchJson('api/notes');
      if (!res.ok || !body) throw new Error(`status ${res.status}`);
      renderNotes(body.notes || [], freshId);
    } catch (err) {
      $('notes').replaceChildren();
      const empty = $('notes-empty');
      empty.hidden = false;
      empty.textContent = `Catatan tidak bisa dimuat (${err.message}). Cek: docker compose logs api`;
    }
  }

  function setNoteStatus(kind, text) {
    const el = $('note-status');
    el.dataset.kind = kind;
    el.textContent = text;
  }

  function wireForm() {
    const form = $('note-form');
    const input = $('note-text');
    const counter = () => setText('note-count', `${input.value.length}/280`);
    input.addEventListener('input', counter);

    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      const text = input.value.trim();
      if (!text) {
        setNoteStatus('bad', 'Catatan masih kosong.');
        return;
      }
      $('note-submit').disabled = true;
      try {
        const { res, body } = await fetchJson('api/notes', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
          body: JSON.stringify({ text }),
        });
        if (res.status !== 201 || !body) {
          throw new Error(body && body.message ? body.message : `status ${res.status}`);
        }
        input.value = '';
        counter();
        setNoteStatus('ok', `Catatan #${body.id} tersimpan (201 Created).`);
        await Promise.all([loadNotes(body.id), checkTiers()]);
      } catch (err) {
        setNoteStatus('bad', `Catatan gagal disimpan: ${err.message}`);
      } finally {
        $('note-submit').disabled = false;
      }
    });
  }

  // ---------- student.json ----------

  async function loadStudent() {
    const line = $('student-line');
    try {
      const res = await fetch('student.json', { cache: 'no-store' });
      if (!res.ok) throw new Error(`status ${res.status}`);
      const s = await res.json();
      const example = s.name === 'Nama Lengkap Anda' || s.github === 'username-github';
      if (example || !s.name) {
        const warn = document.createElement('span');
        warn.className = 'student-warning';
        warn.textContent = 'student.json masih berisi contoh.';
        line.replaceChildren(warn, ' Isi nama, kelas, dan username GitHub Anda di file itu, lalu muat ulang halaman ini.');
        return;
      }
      line.replaceChildren();
      const name = document.createElement('strong');
      name.textContent = s.name;
      line.append('Dikerjakan oleh ', name, ` (${s.class || '-'}), GitHub @${s.github || '-'}`);
    } catch (err) {
      line.textContent = 'student.json tidak terbaca. Pastikan isinya JSON yang valid.';
    }
  }

  // ---------- Mulai ----------

  describeClient();
  wireForm();
  $('recheck').addEventListener('click', () => {
    checkTiers();
    loadWhoami();
  });
  checkTiers();
  loadWhoami();
  loadNotes();
  loadStudent();

  // Periksa ulang otomatis tiap 15 detik selama tab terlihat.
  setInterval(() => {
    if (document.visibilityState === 'visible') checkTiers();
  }, 15000);
})();
