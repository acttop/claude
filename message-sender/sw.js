const CACHE = 'msgsender-v2';
const ASSETS = [
  './',
  './index.html',
  './style.css',
  './app.js',
  './manifest.json',
  './icons/icon.svg',
  './icons/icon-192.png',
  './icons/icon-512.png',
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  e.respondWith(
    caches.match(e.request).then(cached => cached || fetch(e.request))
  );
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  const action = event.action || 'open';
  const ruleId = event.notification.data && event.notification.data.ruleId;

  event.waitUntil((async () => {
    const allClients = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    if (allClients.length) {
      const client = allClients[0];
      client.postMessage({ type: 'autosend-action', ruleId, action });
      await client.focus();
    } else {
      const newClient = await self.clients.openWindow('./index.html');
      if (newClient) {
        setTimeout(() => newClient.postMessage({ type: 'autosend-action', ruleId, action }), 1500);
      }
    }
  })());
});
