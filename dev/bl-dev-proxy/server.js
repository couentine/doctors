/* 
#==========================================================================================================================================#
    
    # BADGE LIST DEVELOPMENT REVERSE PROXY SERVER #

    This is the glue that holds the development environment together. 

    ## The Problem ##

    Because each of the polymer applications run on their own dev server
    and the rails server has its own server, there are issues caused by everything running on different ports. One key issue is that the
    service worker is unable to run at the root level and then still access the polymer apps (thus making service worker un-testable in
    development). Another key issue is that CORS is needed to give the rails app access to run the polymer apps. Another is just that 
    the dev environment is shaped differently than production, leading to potential errors.

    ## The Solution ##

    This is a simple reverse proxy server which takes the urls which correspond to the pre-built polymer files in production and maps them
    to the polymer dev servers. All other urls are directed to the rails dev server. That's it! It irons out all of the kinks.

#==========================================================================================================================================# 
*/

/* #=== CONFIGURATION ===# */

const SERVER_LISTEN_PORT = 4000; // "http://localhost:SERVER_LISTEN_PORT" is how you access badge list in the browser on your dev machine

// The default should point to the rails server.
// The rules should map the polymer build paths specified in `/scripts/deploy.rb` to the ports in the development `Procfile`.
var proxyRuleOptions = {
  rules: {
    '.*/p/app': 'http://localhost:8500',
    '.*/p/website': 'http://localhost:8510'
  },
  default: 'http://localhost:5000'
};

/* #=== HTTP REVERSE PROXY CODE ===# */

// Load libraries
var http = require('http');
var httpProxy = require('http-proxy'); // https://github.com/nodejitsu/node-http-proxy
var httpProxyRules = require('http-proxy-rules'); // https://github.com/donasaur/http-proxy-rules

// Setup proxy rules instance
var proxyRules = new httpProxyRules(proxyRuleOptions);

// Create reverse proxy instance
var proxy = httpProxy.createProxy();

// Create http server that leverages reverse proxy instance
http.createServer(function(req, res) {
  var target = proxyRules.match(req);
  if (target) {
    return proxy.web(req, res, {
      target: target
    });
  }

  res.writeHead(500, { 'Content-Type': 'text/plain' });
  res.end('The request url and path did not match any of the listed rules!');
}).listen(SERVER_LISTEN_PORT);

console.log('Badge List Development Reverse Proxy Server: Listening on port ' + SERVER_LISTEN_PORT + '...');