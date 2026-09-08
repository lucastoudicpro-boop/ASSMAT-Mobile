/* Service worker : l'application reste utilisable sans reseau.
   Changer VERSION force le telechargement de la nouvelle version. */
const VERSION = 'assmat-v1';
const FICHIERS = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icones/icone-192.png',
  './icones/icone-512.png',
  './icones/icone-512-pleine.png'
];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(VERSION).then(c => c.addAll(FICHIERS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(noms => Promise.all(noms.filter(n => n !== VERSION).map(n => caches.delete(n))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  e.respondWith(
    fetch(e.request)
      .then(rep => {
        const copie = rep.clone();
        caches.open(VERSION).then(c => c.put(e.request, copie)).catch(() => {});
        return rep;
      })
      .catch(() => caches.match(e.request).then(r => r || caches.match('./index.html')))
  );
});
