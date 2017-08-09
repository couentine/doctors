Polymer({
  is: "bl-app-navbar-left",

  properties: {
    // Required
    assetPaths: Object,  // stores @assets_paths from application controller
    
    // Optional
    whiteText: { type: Boolean, value: false }
  },

  // Helpers
  getUrl: function(relativeURL) {
    if (this.assetPaths && this.assetPaths.rootURL)
      return this.assetPaths.rootURL + relativeURL;
    else
      return relativeURL;
  }
});
