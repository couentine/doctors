/* ================================================== */
/* ============>> BL APP NAVBAR RIGHT <<============= */
/* ================================================== */

/*
  
  This is the right part of the app navbar which show either a sign in link or the user's avatar
  dropdown menu.

  NOTE: It is necessary to use the getUrl() method to generate urls because normal relative
  paths will break in production (because the javascript files are served from the CDN).

*/

Polymer({
  is: "bl-app-navbar-right",

  properties: {
    // Required
    currentUser: { type: Object, observer: '_currentUserChanged' },
    assetPaths: Object,  // stores @assets_paths from application controller
    
    // Optional
    whiteText: { type: Boolean, value: false },

    // Automatically Set
    isLoggedIn: { type: String, value: false, readOnly: true },

    // Computed
    currentUserProfile: { type: String, computed: "_currentUserProfile(currentUser)" }
  },

  // Observers
  _currentUserChanged: function(newValue, oldValue) {
    this._setIsLoggedIn(newValue && newValue.username_with_caps);
  },

  // Computed Properties
  _currentUserProfile: function(currentUser) { return "/u/" + currentUser.username_with_caps; },

  // Helpers
  getUrl: function(relativeURL) {
    if (this.assetPaths && this.assetPaths.rootURL)
      return this.assetPaths.rootURL + relativeURL;
    else
      return relativeURL;
  }
});
