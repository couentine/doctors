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
if (inProduction) {
  workboxSW.precache([
  {
    "url": "p/app/bower_components/google-fonts-lato/dcGFAl2aezM9Vq_aFTQ.ttf",
    "revision": "d0adc93d1be5bcdb1d6430887c794aa6"
  },
  {
    "url": "p/app/bower_components/google-fonts-roboto-mono/PNLsu_dywMa4C_DEpY50EAVxt0G0biEntp43Qt6E.ttf",
    "revision": "4da5c8b173f9958256a801039a4c60d1"
  },
  {
    "url": "p/app/bower_components/google-fonts-roboto/GBFwfMP4uA6AR0HCoLQ.ttf",
    "revision": "f84c80506d15558a70e3c7752be22177"
  },
  {
    "url": "p/app/bower_components/webcomponentsjs/custom-elements-es5-adapter.js",
    "revision": "a5043c1d0dd16d84558ee6cc2276212e"
  },
  {
    "url": "p/app/bower_components/webcomponentsjs/gulpfile.js",
    "revision": "0366da1f0f7858c9af2daa3ef7d950ea"
  },
  {
    "url": "p/app/bower_components/webcomponentsjs/webcomponents-hi-ce.js",
    "revision": "e0655b55c34560830d28eda5ec51726c"
  },
  {
    "url": "p/app/bower_components/webcomponentsjs/webcomponents-hi-ce.js.map",
    "revision": "64929ec46b398e9c41073001ebab5f5f"
  },
  {
    "url": "p/app/bower_components/webcomponentsjs/webcomponents-hi-sd-ce.js",
    "revision": "ffe437e8a8797cef96b23ced1591b7eb"
  },
  {
    "url": "p/app/bower_components/webcomponentsjs/webcomponents-hi-sd-ce.js.map",
    "revision": "fbd193daaf1ed70d8911d849357857e8"
  },
  {
    "url": "p/app/bower_components/webcomponentsjs/webcomponents-hi.js",
    "revision": "b88ce284fda849097ab4997d97bfc8b6"
  },
  {
    "url": "p/app/bower_components/webcomponentsjs/webcomponents-hi.js.map",
    "revision": "b78e55ca6faca876b6fdc53075e33911"
  },
  {
    "url": "p/app/bower_components/webcomponentsjs/webcomponents-lite.js",
    "revision": "91af6c96521441dd2349d3a0fa83923c"
  },
  {
    "url": "p/app/bower_components/webcomponentsjs/webcomponents-lite.js.map",
    "revision": "97edb64289284c9effa334c6d6d55cac"
  },
  {
    "url": "p/app/bower_components/webcomponentsjs/webcomponents-loader.js",
    "revision": "f13bbbbf647b7922575a7894367ddaaf"
  },
  {
    "url": "p/app/bower_components/webcomponentsjs/webcomponents-sd-ce.js",
    "revision": "2b3ce5380128f1e0e3ad8a130d68cf2a"
  },
  {
    "url": "p/app/bower_components/webcomponentsjs/webcomponents-sd-ce.js.map",
    "revision": "80154d14a7676066d60c5f8ee618a7d3"
  },
  {
    "url": "p/app/bower.json",
    "revision": "65ca57fc991ae1907724408288695c99"
  },
  {
    "url": "p/app/images/badge-list-shield-square.png",
    "revision": "c793c9bc656bd72e8ad4c3974bbe80e9"
  },
  {
    "url": "p/app/images/badge-list-shield-white-square.png",
    "revision": "91456268a90fc9f3b7e3313eb31f207b"
  },
  {
    "url": "p/app/images/ivory-mountiain-trophy.png",
    "revision": "46a1952711888c80c9b0a79408aba5f0"
  },
  {
    "url": "p/app/index.html",
    "revision": "6f4a5629f9defd0028066fbd52355f22"
  },
  {
    "url": "p/app/manifest.json",
    "revision": "56607aebce2f49842f82682481218292"
  },
  {
    "url": "p/app/src/bl-app/bl-app.html",
    "revision": "b7af954125ecd9fb142cfd638d2cb50c"
  },
  {
    "url": "p/app/src/bl-app/bl-component-template.html",
    "revision": "a5a37c812856197f849db3ab2e1b3231"
  },
  {
    "url": "p/app/src/bl-backend/swagger.json",
    "revision": "7b0782807531e15991d73f5cb58c243d"
  },
  {
    "url": "p/app/src/bl-user/bl-user.html",
    "revision": "ddecdbbea58076cbd49a0f8f1a2a42a8"
  },
  {
    "url": "p/app/src/bl-user/test/bl-test-user.html",
    "revision": "e3b61c46b8cecdf0a9103145bfe7fbd0"
  }
]);
}

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