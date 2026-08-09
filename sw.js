// Service Worker — App de Padres LPI
// Estrategia:
//   · HTML / navegación  → red primero (así el deploy nuevo se ve de inmediato),
//     con el cache como respaldo si no hay internet.
//   · Estáticos (iconos, fuentes, CSS de CDN) → cache primero, se refresca en segundo plano.
//   · Supabase (datos reales) → NUNCA se cachea.
const CACHE_NAME = 'lpi-padres-v2';
const APP_SHELL = [
  '/acceso-padres.html',
  '/manifest.json',
  '/fotos/app-icon-192.png',
  '/fotos/app-icon-512.png',
  '/fotos/app-icon-maskable-192.png',
  '/fotos/app-icon-maskable-512.png',
  '/fotos/oso-icon-512.png'
];
// Librerías externas: se precachean una por una para que un fallo de CDN
// no rompa la instalación del service worker.
const EXTERNOS = [
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2',
  'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css'
];

self.addEventListener('install', function (event) {
  event.waitUntil(
    caches.open(CACHE_NAME).then(function (cache) {
      return cache.addAll(APP_SHELL)
        .catch(function () {})
        .then(function () {
          return Promise.all(EXTERNOS.map(function (u) {
            return cache.add(new Request(u, { mode: 'no-cors' })).catch(function () {});
          }));
        });
    }).catch(function () {})
  );
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(
        keys.filter(function (k) { return k !== CACHE_NAME; })
            .map(function (k) { return caches.delete(k); })
      );
    })
  );
  self.clients.claim();
});

self.addEventListener('fetch', function (event) {
  const req = event.request;
  if (req.method !== 'GET') return;
  if (req.url.indexOf('supabase.co') !== -1) return; // datos siempre en vivo

  const esDocumento = req.mode === 'navigate' ||
                      (req.headers.get('accept') || '').indexOf('text/html') !== -1;

  if (esDocumento) {
    // Red primero
    event.respondWith(
      fetch(req).then(function (res) {
        if (res && res.status === 200) {
          const clone = res.clone();
          caches.open(CACHE_NAME).then(function (c) { c.put(req, clone); });
        }
        return res;
      }).catch(function () {
        return caches.match(req).then(function (c) {
          return c || caches.match('/acceso-padres.html');
        });
      })
    );
    return;
  }

  // Estáticos: cache primero + refresco en segundo plano
  event.respondWith(
    caches.match(req).then(function (cached) {
      const red = fetch(req).then(function (res) {
        if (res && res.status === 200) {
          const clone = res.clone();
          caches.open(CACHE_NAME).then(function (c) { c.put(req, clone); });
        }
        return res;
      }).catch(function () { return cached; });
      return cached || red;
    })
  );
});
