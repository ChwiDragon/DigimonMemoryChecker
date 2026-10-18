// DigiMemory Checker web (PWA) service worker: after installing to the home screen, the app opens without internet.
// - Pages (HTML) are fetched fresh when online (updates show up right away), the saved copy is used offline.
// - Everything else (icons, manifest) uses the saved copy first, fetching and saving it when missing.
// Registered at the bottom of memorychecker.html, only on the https site (not in the APK, an artifact or a local file).
const CACHE = 'digimemory-v1';
const PRECACHE = ['./', 'index.html', 'memorychecker.html', 'manifest.webmanifest',
  'pwa/icon-192.png', 'pwa/icon-512.png', 'pwa/icon-maskable-512.png', 'pwa/apple-touch-icon.png'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(PRECACHE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys()
    .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

const keep = (req, res) => {
  if (res && res.ok) {
    const copy = res.clone(); // copy before the page reads the body
    caches.open(CACHE).then((c) => c.put(req, copy));
  }
  return res;
};

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== location.origin) return;
  if (req.mode === 'navigate' || url.pathname.endsWith('.html')) {
    e.respondWith(fetch(req).then((res) => keep(req, res))
      .catch(() => caches.match(req, { ignoreSearch: true }).then((r) => r || caches.match('memorychecker.html'))));
    return;
  }
  e.respondWith(caches.match(req).then((hit) => hit || fetch(req).then((res) => keep(req, res))));
});
