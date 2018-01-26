/*========================================================================================================================================*\

  # BADGE LIST SERVICE WORKER #

  This is an implementation of workbox. It is used to cache network requests for the Badge List app and website.

\*========================================================================================================================================*/

importScripts('workbox-sw.dev.v2.1.2.js');

const workboxSW = new WorkboxSW();
workboxSW.precache([]);

// Dev Assets
workboxSW.router.registerRoute(/http:\/\/localhost:4000\/assets\/.*\.(?:png|gif|jpg|ttf|css|js)/,
  workboxSW.strategies.cacheFirst({
    cacheName: 'assets-cache',
    cacheExpiration: {
      maxEntries: 100,
      maxAgeSeconds: 604800 /* 1 week */
    },
    cacheableResponse: {statuses: [0, 200]}
  })
);

// Polymer Build Files
workboxSW.router.registerRoute(/\/p\/.*/,
  workboxSW.strategies.staleWhileRevalidate({
    cacheName: 'polymer-cache',
    cacheExpiration: {
      maxEntries: 500
    }
  })
);

// S3
workboxSW.router.registerRoute(/https:\/\/[\w-]+\.s3.amazonaws.com\/.*/,
  workboxSW.strategies.cacheFirst({
    cacheName: 's3-cache',
    cacheExpiration: {
      maxEntries: 500,
      maxAgeSeconds: 604800 /* 1 week */
    },
    cacheableResponse: {statuses: [0, 200]}
  })
);

// Google Fonts
workboxSW.router.registerRoute(/https:\/\/(fonts\.googleapis\.com|fonts\.gstatic\.com)\/.*/,
  workboxSW.strategies.cacheFirst({
    cacheName: 'fonts-cache',
    cacheExpiration: {
      maxEntries: 5,
      maxAgeSeconds: 604800 /* 1 week */
    }
  })
);

// Intercom
workboxSW.router.registerRoute(/https:\/\/(js\.intercomcdn\.com|static\.intercomassets\.com)\/.*/,
  workboxSW.strategies.cacheFirst({
    cacheName: 'intercom-cache',
    cacheExpiration: {
      maxEntries: 50,
      maxAgeSeconds: 604800 /* 1 week */
    }
  })
);