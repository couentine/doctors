/*========================================================================================================================================*\

  # BADGE LIST SERVICE WORKER #

  This is an implementation of workbox. It is used to cache network requests for the Badge List app and website.
  This is the source configuration file which is used to register the various regex routes and then link them with cache settings.
  After changing this file you will need to rebuild the sw.js file which is located in `/backend/public`. To do that you can either
  run `/scripts/build-sw.rb` or call `npm run build` on this node project directly.

\*========================================================================================================================================*/

const inProduction = !location || !location.host || !location.host.startsWith('localhost');

if (inProduction) {
  importScripts('workbox-sw.prod.v2.1.2.js');
  importScripts('workbox-broadcast-cache-update.prod.v2.0.3.js');
} else {
  importScripts('workbox-sw.dev.v2.1.2.js');
  importScripts('workbox-broadcast-cache-update.dev.v2.0.3.js');
}

// #=== CONSTANTS ===#

const cacheFirstMaxAgeSeconds = 86400; /* 1 day */

// #=== EVENT LISTENERS ===#

/** Listen for skip waiting message from the service worker UI ("New version available"). */
self.addEventListener('message', (event) => {
  if (!event.data){
    return;
  }

  switch (event.data) {
    case 'skipWaiting':
      self.skipWaiting();
      break;
    default:
      // NOOP
      break;
  }
});

// #=== WORKBOX BOILERPLATE ===#

const workboxSW = new WorkboxSW({
  precacheChannelName: 'bl-revalidate-cache-updates'
});
// NOTE: Not precaching for now. It's being buggy in production.
/*
  if (inProduction) {
    workboxSW.precache([]);
  }
*/

// #=== ROUTE REGISTRATION ===#

// Polymer Build Files
workboxSW.router.registerRoute(/\/p\/.*/,
  workboxSW.strategies.staleWhileRevalidate({
    cacheName: 'polymer-cache',
    cacheExpiration: {
      maxEntries: 200
    },
    plugins: [
      new workbox.broadcastCacheUpdate.BroadcastCacheUpdatePlugin({channelName: 'bl-revalidate-cache-updates'})
    ]
  })
);

// S3
workboxSW.router.registerRoute(/https:\/\/[\w-]+\.s3.amazonaws.com\/.*/,
  workboxSW.strategies.staleWhileRevalidate({
    cacheName: 's3-cache',
    cacheExpiration: {
      maxEntries: 200
    },
    cacheableResponse: {statuses: [0, 200]},
    plugins: [
      new workbox.broadcastCacheUpdate.BroadcastCacheUpdatePlugin({channelName: 'bl-revalidate-cache-updates'})
    ]
  })
);

// Google Fonts
workboxSW.router.registerRoute(/https:\/\/(fonts\.googleapis\.com|fonts\.gstatic\.com)\/.*/,
  workboxSW.strategies.cacheFirst({
    cacheName: 'fonts-cache',
    cacheExpiration: {
      maxEntries: 5,
      maxAgeSeconds: cacheFirstMaxAgeSeconds
    }
  })
);

// Intercom
workboxSW.router.registerRoute(/https:\/\/(js\.intercomcdn\.com|static\.intercomassets\.com)\/.*/,
  workboxSW.strategies.cacheFirst({
    cacheName: 'intercom-cache',
    cacheExpiration: {
      maxEntries: 20,
      maxAgeSeconds: cacheFirstMaxAgeSeconds
    }
  })
);