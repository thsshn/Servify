// Servify – Service Worker v3
const CACHE_VERSION = 'v3';
const STATIC_CACHE = `servify-static-${CACHE_VERSION}`;
const DYNAMIC_CACHE = `servify-dynamic-${CACHE_VERSION}`;

const STATIC_ASSETS = [
  '/',
  '/offline.html',
  '/manifest.json',
  '/icons/icon-192x192.png',
  '/icons/icon-512x512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => cache.addAll(STATIC_ASSETS))
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key.startsWith('servify-') && !key.endsWith(CACHE_VERSION))
          .map((key) => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  if (request.method !== 'GET') return;
  if (!url.protocol.startsWith('http')) return;
  // Skip cross-origin requests (Google Fonts, Supabase, CDN)
  if (url.origin !== self.location.origin) return;

  if (url.pathname.startsWith('/api/')) {
    event.respondWith(networkFirst(request));
    return;
  }

  if (request.destination === 'image' || request.destination === 'style' || request.destination === 'script') {
    event.respondWith(cacheFirst(request));
    return;
  }

  if (request.destination === 'document') {
    event.respondWith(staleWhileRevalidate(request));
    return;
  }
});

async function cacheFirst(request) {
  const cached = await caches.match(request);
  if (cached) return cached;
  try {
    const response = await fetch(request);
    if (response.ok) (await caches.open(STATIC_CACHE)).put(request, response.clone());
    return response;
  } catch {
    return new Response('Unavailable offline.', { status: 503 });
  }
}

async function networkFirst(request) {
  const cache = await caches.open(DYNAMIC_CACHE);
  try {
    const response = await fetch(request);
    if (response.ok) cache.put(request, response.clone());
    return response;
  } catch {
    return (await cache.match(request)) || new Response(JSON.stringify({ error: 'Offline' }), {
      status: 503, headers: { 'Content-Type': 'application/json' }
    });
  }
}

async function staleWhileRevalidate(request) {
  const cache = await caches.open(DYNAMIC_CACHE);
  const cached = await cache.match(request);
  const fetchPromise = fetch(request).then((r) => {
    if (r.ok) cache.put(request, r.clone());
    return r;
  }).catch(async () => (await caches.match('/offline.html')) || new Response('Offline', { status: 503 }));
  return cached || fetchPromise;
}

self.addEventListener('push', (event) => {
  const data = event.data?.json() ?? {};
  event.waitUntil(self.registration.showNotification(data.title || 'Servify', {
    body: data.body || 'You have a new notification.',
    icon: '/icons/icon-192x192.png',
    badge: '/icons/icon-72x72.png',
    data: { url: data.url || '/' },
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(clients.openWindow(event.notification.data?.url || '/'));
});
