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
    "revision": "88b9ef2940d02f17312ab0ad5438d171"
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
    "revision": "838b174cb70562b47cc73e7e01968015"
  },
  {
    "url": "p/app/src/bl-app/bl-app.html",
    "revision": "b1201e4773f1d03471f6e11c5ca583d9"
  },
  {
    "url": "p/app/src/bl-app/bl-component-template.html",
    "revision": "a5a37c812856197f849db3ab2e1b3231"
  },
  {
    "url": "p/app/src/bl-user/bl-user.html",
    "revision": "ddecdbbea58076cbd49a0f8f1a2a42a8"
  },
  {
    "url": "p/app/src/bl-user/test/bl-test-user.html",
    "revision": "e3b61c46b8cecdf0a9103145bfe7fbd0"
  },
  {
    "url": "p/website/bower_components/google-fonts-lato/dcGFAl2aezM9Vq_aFTQ.ttf",
    "revision": "d0adc93d1be5bcdb1d6430887c794aa6"
  },
  {
    "url": "p/website/bower_components/google-fonts-roboto-mono/PNLsu_dywMa4C_DEpY50EAVxt0G0biEntp43Qt6E.ttf",
    "revision": "4da5c8b173f9958256a801039a4c60d1"
  },
  {
    "url": "p/website/bower_components/google-fonts-roboto/GBFwfMP4uA6AR0HCoLQ.ttf",
    "revision": "f84c80506d15558a70e3c7752be22177"
  },
  {
    "url": "p/website/bower_components/webcomponentsjs/custom-elements-es5-adapter.js",
    "revision": "a5043c1d0dd16d84558ee6cc2276212e"
  },
  {
    "url": "p/website/bower_components/webcomponentsjs/gulpfile.js",
    "revision": "0366da1f0f7858c9af2daa3ef7d950ea"
  },
  {
    "url": "p/website/bower_components/webcomponentsjs/webcomponents-hi-ce.js",
    "revision": "fbaa6751e3b07a33a459ebbbd24a4ede"
  },
  {
    "url": "p/website/bower_components/webcomponentsjs/webcomponents-hi-ce.js.map",
    "revision": "8fe4315ebe24b527ee2a8e0142861b97"
  },
  {
    "url": "p/website/bower_components/webcomponentsjs/webcomponents-hi-sd-ce.js",
    "revision": "f06beb1fba0a9020e116162370e3ef16"
  },
  {
    "url": "p/website/bower_components/webcomponentsjs/webcomponents-hi-sd-ce.js.map",
    "revision": "fd5488d25baef1169a2cd23804df4b35"
  },
  {
    "url": "p/website/bower_components/webcomponentsjs/webcomponents-hi.js",
    "revision": "487ac7582563f4797e9e3659a096a642"
  },
  {
    "url": "p/website/bower_components/webcomponentsjs/webcomponents-hi.js.map",
    "revision": "72440787e3c9ca0204264a6f8e996d24"
  },
  {
    "url": "p/website/bower_components/webcomponentsjs/webcomponents-lite.js",
    "revision": "b591b76678e2f5d584eff169fd0ff2f8"
  },
  {
    "url": "p/website/bower_components/webcomponentsjs/webcomponents-lite.js.map",
    "revision": "aee6a8694425d33c8a335ed3c8aa4825"
  },
  {
    "url": "p/website/bower_components/webcomponentsjs/webcomponents-loader.js",
    "revision": "f13bbbbf647b7922575a7894367ddaaf"
  },
  {
    "url": "p/website/bower_components/webcomponentsjs/webcomponents-sd-ce.js",
    "revision": "e229eae539aba7a4d2400316e6603b0d"
  },
  {
    "url": "p/website/bower_components/webcomponentsjs/webcomponents-sd-ce.js.map",
    "revision": "099adab476e3ed933f271956a5cf9cf7"
  },
  {
    "url": "p/website/bower.json",
    "revision": "a974681091b584158e2e868e89047c4e"
  },
  {
    "url": "p/website/images/badge-list-shield-square.png",
    "revision": "c793c9bc656bd72e8ad4c3974bbe80e9"
  },
  {
    "url": "p/website/images/badge-list-shield-white-square.png",
    "revision": "91456268a90fc9f3b7e3313eb31f207b"
  },
  {
    "url": "p/website/index.html",
    "revision": "d554b649fd1c4b0da4e07cc8f18ad5be"
  },
  {
    "url": "p/website/manifest.json",
    "revision": "87dc70ac6fa1c4b0b961009acf7c4a0a"
  },
  {
    "url": "p/website/src/bl-website/bl-website.html",
    "revision": "a8f7c1405aa114604367e90ea19dc56d"
  }
]);
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