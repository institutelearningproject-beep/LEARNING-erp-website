// Service Worker — Portal de Padres LPI
// Cachea el "cascarón" de la app para carga instantánea/offline.
// Las llamadas a Supabase (datos reales: calificaciones, asistencia, etc.) NUNCA se cachean.
const CACHE_NAME = 'lpi-padres-v1';
const APP_SHELL = [
  '/acceso-padres.html',
  '/manifest.json',
  '/fotos/oso-icon-192.png',
  '/fotos/oso-icon-512.png'
];

self.addEventListener('install', function(event) {
  event.waitUntil(
    caches.open(CACHE_NAME).then(function(cache) { return cache.addAll(APP_SHELL); }).catch(function(){})
  );
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  event.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(keys.filter(function(k){ return k !== CACHE_NAME; }).map(function(k){ return caches.delete(k); }));
    })
  );
  self.clients.claim();
});

self.addEventListener('fetch', function(event) {
  const req = event.request;
  if (req.method !== 'GET') return;
  if (req.url.indexOf('supabase.co') !== -1) return; // datos siempre en vivo
  event.respondWith(
    caches.match(req).then(function(cached) {
      const fetchPromise = fetch(req).then(function(res) {
        if (res && res.status === 200) {
          const resClone = res.clone();
          caches.open(CACHE_NAME).then(function(cache){ cache.put(req, resClone); });
        }
        return res;
      }).catch(function(){ return cached; });
      return cached || fetchPromise;
    })
  );
});
