Polymer({
  is: "bl-app-container",

  properties: {
    // Required
    colorMode: String, // = ['home', 'group']
    currentUser: Object,
    
    // Optional
    appbarMode: {
      type: String,
      value: 'standard' // = ['standard', 'home']
    },
    backgroundMode: {
      type: String,
      value: 'standard' // = ['standard', 'color']
    },
    headerMode: {
      type: String,
      value: 'standard' //= paper-header-panel modes OR 'condensable' for paper-scroll-header-panel
    },
    toolbarMode: {
      type: String,
      value: '' // = paper-toolbar class values
    },
    
    // Mode-Specific
    condensedHeaderHeight: {
      type: Number,
      value: 140
    },
    headerHeight: {
      type: Number,
      value: 256
    },

    // Computed
    currentUserProfile: {
      type: String,
      computed: "_currentUserProfile(currentUser)"
    },
    headerPanelClass: {
      type: String,
      computed: "_headerPanelClass(backgroundMode, colorMode)"
    },
    toolbarClass: {
      type: String,
      computed: "_toolbarClass(backgroundMode, colorMode, toolbarMode)"
    },
    isAppbarMode_Standard: {
      type: Boolean,
      computed: "_isAppbarMode_Standard(appbarMode)"
    },
    isAppbarMode_Home: {
      type: Boolean,
      computed: "_isAppbarMode_Home(appbarMode)"
    },
    isHeaderMode_Condensable: {
      type: Boolean,
      computed: "_isHeaderMode_Condensable(headerMode)"
    }
  },

  // Computed Properties
  _currentUserProfile: function(currentUser) { return "/u/" + currentUser.username_with_caps; },
  _headerPanelClass: function(backgroundMode, colorMode) { 
    return colorMode + "-color " + backgroundMode + "-background "; 
  },
  _toolbarClass: function(backgroundMode, colorMode, toolbarMode) { 
    return colorMode + "-color " + backgroundMode + "-background " + toolbarMode; 
  },
  _isAppbarMode_Standard: function(appbarMode) { return appbarMode == "standard"; },
  _isAppbarMode_Home: function(appbarMode) { return appbarMode == "home"; },
  _isHeaderMode_Condensable: function(headerMode) { return headerMode == "condensable"; }
});
