'use strict';

// =============================================================================
// Net Web Lab API (Praktikum Pertemuan 3)
// Node.js tanpa framework: hanya modul bawaan node:http + driver PostgreSQL "pg".
// Semua jawaban berupa JSON (UTF-8), kecuali /api/bytes (file contoh).
//
// Daftar endpoint: GET /api/  (atau lihat README bagian API).
// Setiap request dicatat satu baris di log:  docker compose logs -f api
// =============================================================================

const http = require('node:http');
const os = require('node:os');
const { Readable, pipeline } = require('node:stream');
const { setTimeout: sleep } = require('node:timers/promises');
const { Pool } = require('pg');

const PORT = Number(process.env.PORT || 3000);
const MAX_DELAY_MS = 5000;        // /api/delay dibatasi 5 detik
const MAX_KB = 51200;             // /api/bytes dibatasi 50 MB
const MAX_NOTE_LENGTH = 280;      // panjang maksimum satu catatan
const MAX_BODY_BYTES = 16 * 1024; // batas ukuran body POST

// PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE dibaca otomatis oleh "pg"
// dari environment variable (lihat bagian environment service api di compose.yaml).
const pool = new Pool({
  max: 5,
  connectionTimeoutMillis: 2000,
  idleTimeoutMillis: 30000,
  query_timeout: 5000,
});
// Tanpa handler ini, koneksi idle yang putus (misalnya db di-restart) membuat proses crash.
pool.on('error', (err) => console.error(`pg: koneksi idle error: ${err.message}`));

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

function sendJson(res, status, body, headers = {}) {
  const data = JSON.stringify(body, null, 2) + '\n';
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(data),
    'Cache-Control': 'no-store',
    ...headers,
  });
  res.end(res.req.method === 'HEAD' ? undefined : data);
}

function sendError(res, status, error, message, headers) {
  sendJson(res, status, { error, message }, headers);
}

// "::ffff:172.28.20.2" (IPv4 di socket IPv6) -> "172.28.20.2"
function cleanIp(ip) {
  return typeof ip === 'string' ? ip.replace(/^::ffff:/, '') : null;
}

function isLoopback(ip) {
  return ip === '127.0.0.1' || ip === '::1';
}

// Database mati / tidak terjangkau: jawab 503 (Service Unavailable), bukan 500.
const DB_DOWN_CODES = ['ECONNREFUSED', 'ENOTFOUND', 'EAI_AGAIN', 'ETIMEDOUT', 'EHOSTUNREACH', '57P01', '57P03'];
function isDbUnavailable(err) {
  return DB_DOWN_CODES.includes(err.code) || /connection timeout|connection terminated/i.test(err.message);
}

// Alamat IPv4 container ini di setiap jaringan Docker (satu interface per jaringan).
function containerAddresses() {
  const out = [];
  for (const [iface, addrs] of Object.entries(os.networkInterfaces())) {
    for (const a of addrs || []) {
      if (a.family === 'IPv4' && !a.internal) out.push({ interface: iface, address: a.address, cidr: a.cidr });
    }
  }
  return out.sort((x, y) => x.address.localeCompare(y.address, 'en', { numeric: true }));
}

function intParam(url, name, fallback) {
  const raw = url.searchParams.get(name);
  if (raw === null || raw === '') return fallback;
  if (!/^\d{1,9}$/.test(raw)) return NaN;
  return Number(raw);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    let tooLarge = false;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) tooLarge = true;
      else chunks.push(chunk);
    });
    req.on('end', () => {
      if (tooLarge) reject(Object.assign(new Error('body terlalu besar'), { status: 413 }));
      else resolve(Buffer.concat(chunks).toString('utf8'));
    });
    req.on('error', reject);
  });
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

function index(req, res) {
  sendJson(res, 200, {
    service: 'api',
    message: 'Net Web Lab API. Panggil endpoint di bawah dengan curl atau wget.',
    endpoints: [
      'GET  /api/health           status API + database (200 atau 503)',
      'GET  /api/whoami           apa yang dilihat API tentang request Anda',
      'GET  /api/notes            daftar catatan',
      'POST /api/notes            tambah catatan, body JSON {"text": "..."}',
      'GET  /api/notes/:id        satu catatan (404 bila tidak ada)',
      'GET  /api/delay?ms=800     jawaban sengaja ditunda (maks 5000 ms)',
      'GET  /api/status/:kode     jawaban dengan status code 200-599',
      'GET  /api/redirect?n=1     redirect 302 berantai n kali ke /api/health',
      'GET  /api/bytes?kb=1024    file contoh untuk wget (maks 51200 KB, opsional &rate=KB/s)',
    ],
  });
}

async function health(req, res) {
  const base = { service: 'api' };
  const meta = { hostname: os.hostname(), time: new Date().toISOString() };
  try {
    const { rows } = await pool.query(
      "SELECT current_setting('server_version') AS version, (SELECT count(*)::int FROM notes) AS notes",
    );
    sendJson(res, 200, {
      status: 'ok',
      ...base,
      db: 'up',
      ...meta,
      db_version: `PostgreSQL ${rows[0].version}`,
      notes: rows[0].notes,
      node: process.version,
      uptime_s: Math.round(process.uptime()),
    });
  } catch (err) {
    sendJson(res, 503, { status: 'error', ...base, db: 'down', ...meta, error: err.message });
  }
}

function whoami(req, res) {
  const h = req.headers;
  const viaProxy = Boolean(h['x-forwarded-for']);
  sendJson(res, 200, {
    service: 'api',
    hostname: os.hostname(),
    addresses: containerAddresses(),
    remoteAddress: cleanIp(req.socket.remoteAddress),
    remotePort: req.socket.remotePort,
    httpVersion: req.httpVersion,
    method: req.method,
    url: req.url,
    viaProxy,
    headers: {
      host: h.host ?? null,
      'user-agent': h['user-agent'] ?? null,
      'x-forwarded-for': h['x-forwarded-for'] ?? null,
      'x-real-ip': h['x-real-ip'] ?? null,
      'x-forwarded-proto': h['x-forwarded-proto'] ?? null,
    },
    note: viaProxy
      ? 'Lewat reverse proxy: remoteAddress adalah IP nginx, IP klien asli ada di X-Forwarded-For / X-Real-IP.'
      : 'Langsung ke API tanpa reverse proxy: remoteAddress adalah IP klien itu sendiri.',
  });
}

async function listNotes(req, res) {
  const { rows } = await pool.query('SELECT id, text, created_at FROM notes ORDER BY id DESC LIMIT 50');
  sendJson(res, 200, { count: rows.length, notes: rows });
}

async function createNote(req, res) {
  let raw;
  try {
    raw = await readBody(req);
  } catch (err) {
    return sendError(res, err.status || 400, 'bad_body', `Body tidak bisa dibaca: ${err.message}`);
  }

  let text;
  const type = String(req.headers['content-type'] || '');
  if (type.includes('application/x-www-form-urlencoded') && !raw.trim().startsWith('{')) {
    text = new URLSearchParams(raw).get('text');          // curl -d 'text=halo' juga diterima
  } else {
    let data;
    try {
      data = JSON.parse(raw);
    } catch {
      return sendError(res, 400, 'bad_json', 'Body harus JSON valid, contoh: {"text": "halo"}');
    }
    text = data && typeof data === 'object' ? data.text : undefined;
  }

  if (typeof text !== 'string' || text.trim().length === 0 || text.trim().length > MAX_NOTE_LENGTH) {
    return sendError(res, 400, 'invalid_text', `Field "text" wajib diisi (1-${MAX_NOTE_LENGTH} karakter).`);
  }

  const { rows } = await pool.query(
    'INSERT INTO notes (text) VALUES ($1) RETURNING id, text, created_at',
    [text.trim()],
  );
  sendJson(res, 201, rows[0], { Location: `/api/notes/${rows[0].id}` });
}

async function getNote(req, res, idText) {
  if (!/^\d{1,9}$/.test(idText)) {
    return sendError(res, 400, 'bad_id', 'ID catatan harus berupa angka, contoh: /api/notes/1');
  }
  const { rows } = await pool.query('SELECT id, text, created_at FROM notes WHERE id = $1', [Number(idText)]);
  if (rows.length === 0) return sendError(res, 404, 'not_found', `Catatan #${idText} tidak ada.`);
  sendJson(res, 200, rows[0]);
}

async function delay(req, res, url) {
  const ms = intParam(url, 'ms', 1000);
  if (Number.isNaN(ms)) return sendError(res, 400, 'bad_ms', 'Parameter ms harus angka, contoh: /api/delay?ms=800');
  const waited = Math.min(ms, MAX_DELAY_MS);
  await sleep(waited);
  if (res.destroyed) return; // klien sudah pergi (misalnya curl --max-time)
  sendJson(res, 200, { delayed_ms: waited, requested_ms: ms, capped: ms > MAX_DELAY_MS });
}

function status(req, res, codeText) {
  const code = Number(codeText);
  if (!/^\d{3}$/.test(codeText) || code < 200 || code > 599) {
    return sendError(res, 400, 'bad_status', 'Gunakan kode 200 sampai 599, contoh: /api/status/404');
  }
  if (code === 204 || code === 205 || code === 304) {       // status tanpa body
    res.writeHead(code, { 'Cache-Control': 'no-store' });
    return res.end();
  }
  sendJson(res, code, { status: code, message: http.STATUS_CODES[code] || 'Unknown' });
}

function redirect(req, res, url) {
  const n = intParam(url, 'n', 1);
  if (Number.isNaN(n) || n < 1 || n > 5) return sendError(res, 400, 'bad_n', 'Parameter n harus 1 sampai 5.');
  const location = n > 1 ? `/api/redirect?n=${n - 1}` : '/api/health';
  sendJson(res, 302, { message: `Dialihkan ke ${location}`, remaining: n - 1 }, { Location: location });
}

// Isi file contoh berupa baris 16 byte: "netlab-00000000\n", "netlab-00000001\n", ...
// Isinya bisa dihitung dari posisi byte, sehingga download yang dilanjutkan
// (wget -c, header Range) menghasilkan file yang identik dengan download penuh.
const LINE_BYTES = 16;
const LINES_PER_CHUNK = 4096; // 64 KB per potongan

function chunkAt(lineNo) {
  let s = '';
  for (let i = 0; i < LINES_PER_CHUNK; i += 1) s += `netlab-${String(lineNo + i).padStart(8, '0')}\n`;
  return Buffer.from(s, 'ascii');
}

async function* sampleBytes(start, end, rate) {
  const t0 = Date.now();
  let pos = start;
  let sent = 0;
  while (pos <= end) {
    const firstLine = Math.floor(pos / LINE_BYTES);
    const chunkStart = firstLine * LINE_BYTES;
    const buf = chunkAt(firstLine).subarray(pos - chunkStart, Math.min(LINES_PER_CHUNK * LINE_BYTES, end - chunkStart + 1));
    yield buf;
    pos += buf.length;
    sent += buf.length;
    if (rate && pos <= end) {
      const due = (sent / (rate * 1024)) * 1000 - (Date.now() - t0);
      if (due > 0) await sleep(due);
    }
  }
}

function bytes(req, res, url) {
  const kb = intParam(url, 'kb', 1024);
  const rate = intParam(url, 'rate', 0);
  if (Number.isNaN(kb) || kb < 1) return sendError(res, 400, 'bad_kb', 'Parameter kb harus angka >= 1, contoh: /api/bytes?kb=5120');
  if (Number.isNaN(rate)) return sendError(res, 400, 'bad_rate', 'Parameter rate (KB/detik) harus angka.');
  const sizeKb = Math.min(kb, MAX_KB);
  const total = sizeKb * 1024;
  const headers = {
    'Content-Type': 'application/octet-stream',
    'Content-Disposition': `attachment; filename="sample-${sizeKb}kb.bin"`,
    'Accept-Ranges': 'bytes',
    'Cache-Control': 'no-store',
    'X-Accel-Buffering': 'no', // minta nginx langsung meneruskan data (tanpa buffering)
  };

  let start = 0;
  let end = total - 1;
  let code = 200;
  const range = /^bytes=(\d*)-(\d*)$/.exec(String(req.headers.range || '').trim());
  if (range && (range[1] !== '' || range[2] !== '')) {
    if (range[1] === '') {               // bytes=-N  (N byte terakhir)
      start = Math.max(0, total - Number(range[2]));
    } else {
      start = Number(range[1]);
      if (range[2] !== '') end = Math.min(Number(range[2]), total - 1);
    }
    if (start >= total || start > end) {
      res.writeHead(416, { 'Content-Range': `bytes */${total}`, 'Cache-Control': 'no-store' });
      return res.end();
    }
    code = 206;
    headers['Content-Range'] = `bytes ${start}-${end}/${total}`;
  }
  headers['Content-Length'] = end - start + 1;
  res.writeHead(code, headers);
  if (req.method === 'HEAD') return res.end();

  const effectiveRate = rate > 0 ? Math.max(16, rate) : 0;
  pipeline(Readable.from(sampleBytes(start, end, effectiveRate)), res, () => {});
}

// ---------------------------------------------------------------------------
// Routing
// ---------------------------------------------------------------------------

const routes = [
  { re: /^\/(?:api\/?)?$/, methods: ['GET', 'HEAD'], run: (req, res) => index(req, res) },
  { re: /^\/api\/health\/?$/, methods: ['GET', 'HEAD'], run: (req, res) => health(req, res) },
  { re: /^\/api\/whoami\/?$/, methods: ['GET', 'HEAD'], run: (req, res) => whoami(req, res) },
  {
    re: /^\/api\/notes\/?$/,
    methods: ['GET', 'HEAD', 'POST'],
    run: (req, res) => (req.method === 'POST' ? createNote(req, res) : listNotes(req, res)),
  },
  { re: /^\/api\/notes\/([^/]+)\/?$/, methods: ['GET', 'HEAD'], run: (req, res, m) => getNote(req, res, m[1]) },
  { re: /^\/api\/delay\/?$/, methods: ['GET', 'HEAD'], run: (req, res, m, url) => delay(req, res, url) },
  { re: /^\/api\/status\/([^/]+)\/?$/, methods: ['GET', 'HEAD', 'POST', 'PUT', 'DELETE'], run: (req, res, m) => status(req, res, m[1]) },
  { re: /^\/api\/redirect\/?$/, methods: ['GET', 'HEAD'], run: (req, res, m, url) => redirect(req, res, url) },
  { re: /^\/api\/bytes\/?$/, methods: ['GET', 'HEAD'], run: (req, res, m, url) => bytes(req, res, url) },
];

async function handle(req, res) {
  const url = new URL(req.url, 'http://api.local');
  for (const route of routes) {
    const m = route.re.exec(url.pathname);
    if (!m) continue;
    if (!route.methods.includes(req.method)) {
      return sendError(res, 405, 'method_not_allowed', `Method ${req.method} tidak didukung di ${url.pathname}.`, {
        Allow: route.methods.join(', '),
      });
    }
    return route.run(req, res, m, url);
  }
  sendError(res, 404, 'not_found', `Tidak ada endpoint ${url.pathname}. Daftar endpoint: GET /api/`);
}

// Satu baris log per request: waktu, method, path, status, durasi, user-agent,
// X-Forwarded-For, dan alamat yang membuka koneksi TCP.
// Request dari 127.0.0.1 (healthcheck Docker) tidak dicatat supaya log tetap bersih.
function logRequest(req, res, t0, from) {
  if (isLoopback(from)) return;
  const ms = Number(process.hrtime.bigint() - t0) / 1e6;
  const aborted = res.writableFinished ? '' : ' (klien memutus koneksi)';
  const code = res.headersSent ? res.statusCode : '---';
  console.log(
    `${new Date().toISOString()} ${req.method} ${req.url} ${code} ${ms.toFixed(0)}ms` +
      ` ua="${req.headers['user-agent'] || '-'}" xff="${req.headers['x-forwarded-for'] || '-'}" from=${from}${aborted}`,
  );
}

const server = http.createServer((req, res) => {
  const t0 = process.hrtime.bigint();
  const from = cleanIp(req.socket.remoteAddress); // dicatat di awal: saat 'close' socket bisa sudah hilang
  res.on('close', () => logRequest(req, res, t0, from));
  handle(req, res).catch((err) => {
    console.error(`error ${req.method} ${req.url}: ${err.message}`);
    if (res.headersSent) return res.destroy();
    if (isDbUnavailable(err)) sendError(res, 503, 'db_unavailable', `Database tidak bisa dihubungi: ${err.message}`);
    else sendError(res, 500, 'internal_error', err.message);
  });
});

server.listen(PORT, () => {
  const ips = containerAddresses().map((a) => a.address).join(', ');
  console.log(`api siap di port ${PORT} (hostname ${os.hostname()}, IP ${ips || '-'})`);
});

function shutdown(signal) {
  console.log(`${signal} diterima, api berhenti.`);
  server.close();
  server.closeIdleConnections();
  pool.end().finally(() => process.exit(0));
  setTimeout(() => process.exit(0), 3000).unref();
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
