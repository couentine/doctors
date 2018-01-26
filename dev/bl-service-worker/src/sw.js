/*========================================================================================================================================*\

  # BADGE LIST SERVICE WORKER #

  This is an implementation of workbox. It is used to cache network requests for the Badge List app and website.

\*========================================================================================================================================*/

importScripts('workbox-sw.dev.v2.1.2.js');

const workboxSW = new WorkboxSW();
workboxSW.precache([]);

workboxSW.router.registerRoute(/assets\/.*\.(?:png|gif|jpg|ttf|css|js)/,
  workboxSW.strategies.cacheFirst({
    cacheName: 'assets-cache',
    cacheExpiration: {
      maxEntries: 100
    },
    cacheableResponse: {statuses: [0, 200]}
  })
);

workboxSW.router.registerRoute(/p\/.*/,
  workboxSW.strategies.cacheFirst({
    cacheName: 'polymer-cache',
    cacheExpiration: {
      maxEntries: 500
    }
  })
);

workboxSW.router.registerRoute(/https:\/\/(fonts\.googleapis\.com|fonts\.gstatic\.com)\/.*/,
  workboxSW.strategies.cacheFirst({
    cacheName: 'fonts-cache',
    cacheExpiration: {
      maxEntries: 5
    }
  })
);