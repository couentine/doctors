Polymer({
  is: "bl-app-container",

  properties: {
    // Required
    colorMode: String, // = ['home', 'group']
    
    // Optional
    appbarMode: {
      type: String,
      value: 'standard' // = ['standard', 'home']
    },
    headerMode: {
      type: String,
      value: 'standard' // = paper-header-panel modes
    },
    toolbarMode: {
      type: String,
      value: '' // = paper-toolbar class values
    },
    backgroundMode: {
      type: String,
      value: 'standard' // = ['standard', 'color']
    },

    // Computed
    headerPanelClass: {
      type: String,
      computed: "_headerPanelClass(colorMode)"
    },
    toolbarClass: {
      type: String,
      computed: "_toolbarClass(colorMode, toolbarMode)"
    },
    isAppbarMode_Standard: {
      type: Boolean,
      computed: "_isAppbarMode_Standard(appbarMode)"
    },
    isAppbarMode_Home: {
      type: Boolean,
      computed: "_isAppbarMode_Home(appbarMode)"
    }
  },

  // Computed Properties
  _headerPanelClass: function(colorMode) { return colorMode + "-colors"; },
  _toolbarClass: function(colorMode, toolbarMode) { 
    return toolbarMode + " " + colorMode + "-colors"; 
  },
  _isAppbarMode_Standard: function(appbarMode) { return appbarMode == "standard"; },
  _isAppbarMode_Home: function(appbarMode) { return appbarMode == "home"; }
});
