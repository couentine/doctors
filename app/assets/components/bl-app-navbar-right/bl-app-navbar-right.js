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
