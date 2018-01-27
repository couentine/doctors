module.exports = {
  "globDirectory": "../../backend/public/",
  "globPatterns": [
    "p/**/*.{html,json,ttf,js,map,png,txt}"
  ],
  "swSrc": "src/sw.js",
  "swDest": "../../backend/public/sw.js",
  "globIgnores": [
    "../../dev/bl-service-worker/workbox-cli-config.js"
  ]
};
