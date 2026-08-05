const CACHE = 'msgsender-v3';
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
  // 온라인이면 항상 최신 파일을 먼저 받아온다(캐시는 오프라인 대비 백업 용도).
  // 순수 캐시 우선 전략은 배포한 새 버전이 반영 안 되는 문제가 있었다.
  e.respondWith(
    fetch(e.request)
      .then(res => {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put(e.request, copy));
        return res;
      })
      .catch(() => caches.match(e.request))
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
