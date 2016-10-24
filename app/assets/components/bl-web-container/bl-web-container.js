Polymer({
  is: 'bl-web-container',

  properties: {
    // Required
    pageName: String, // = ['home', 'how-it-works']
    currentUser: { type: Object, value: null },
    assetPaths: { type: Object, notify: true },  // from application controller
    
    // Mode-Specific
    headerHeight: { type: Number, value: 256 },

    // Computed
    isLoggedIn: { type: Boolean, computed: '_isLoggedIn(currentUser)' },
    urlProfile: { type: String, computed: '_urlProfile(assetPaths, currentUser)' },
    headerPanelClass: { type: String, computed: '_headerPanelClass(pageName)' },
    toolbarClass: { type: String, computed: '_toolbarClass(pageName)'},

    urlAdmin: { type: String, computed: '_urlAdmin(assetPaths)' },
    urlChangeImage: { type: String, computed: '_urlChangeImage(assetPaths)' },
    urlHome: { type: String, computed: '_urlHome(assetPaths)' },
    urlManageAccount: { type: String, computed: '_urlManageAccount(assetPaths)' },
    urlSignIn: { type: String, computed: '_urlSignIn(assetPaths)' },
    urlSignOut: { type: String, computed: '_urlSignOut(assetPaths)' }
  },

  // Events
  ready: function() {},
  attached: function() {},

  // Computed Properties
  _isLoggedIn: function(currentUser, forceUserUpdate) { 
    return (currentUser != null) &&  (currentUser.id != null); 
  },
  _headerPanelClass: function(pageName) { return pageName + '-page'; },
  _toolbarClass: function(pageName) { return pageName + '-page'; },

  _urlProfile: function(currentUser) { 
    if (currentUser == null) return '#';
    else return '/u/' + currentUser.username_with_caps; 
  },
  _urlAdmin: function(assetPaths) { return this.getURL('/a'); },
  _urlChangeImage: function(assetPaths) { return this.getURL('/users/edit#upload-image'); },
  _urlHome: function(assetPaths) { return this.getURL('/'); },
  _urlManageAccount: function(assetPaths) { return this.getURL('/users/edit'); },
  _urlSignIn: function(assetPaths) { return this.getURL('/users/sign_in'); },
  _urlSignOut: function(assetPaths) { return this.getURL('/users/sign_out'); },

  // Helpers
  getURL: function(relativeURL) { return this.assetPaths.rootURL + relativeURL; }
});
