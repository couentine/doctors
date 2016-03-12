Polymer({
  is: "bl-app-container",

  properties: {
    // Required
    colorMode: String, // = ['home', 'group']
    currentUser: Object,
    assetPaths: Object,  // stores @assets_paths from application controller
    
    // Optional
    appbarMode: { type: String, value: 'standard' }, // = ['standard', 'home']
    backgroundMode: { type: String, value: 'standard' }, // = ['standard', 'color']
    hasCustomLogo: Boolean,
    headerMode: { type: String, value: 'standard' },
      //= paper-header-panel modes OR 'condensable' for paper-scroll-header-panel
    toolbarMode: { type: String, value: '' }, // = paper-toolbar class values
    hideIntercom: { type: Boolean, value: false },
    
    // Mode-Specific
    condensedHeaderHeight: { type: Number, value: 140 },
    headerHeight: { type: Number, value: 256 },

    // Computed
    currentUserProfile: { type: String, computed: "_currentUserProfile(currentUser)" },
    headerPanelClass: { type: String, computed: "_headerPanelClass(backgroundMode, colorMode)" },
    toolbarClass: { type: String, 
      computed: "_toolbarClass(backgroundMode,colorMode,toolbarMode,headerMode)"},
    isAppbarMode_Standard: { type: Boolean, computed: "_isAppbarMode_Standard(appbarMode)" },
    isAppbarMode_Home: { type: Boolean, computed: "_isAppbarMode_Home(appbarMode)" },
    isHeaderMode_Condensable: { type: Boolean, computed: "_isHeaderMode_Condensable(headerMode)" }
  },

  // Events
  ready: function() {
    // We need to manually fix any paper drowndown menus if present
    // Details here: https://github.com/PolymerElements/paper-dropdown-menu/issues/10
    document.addEventListener('WebComponentsReady', function() {
      var paper_dropdowns = document.querySelectorAll('paper-dropdown-menu');
      for(var a = 0; a < paper_dropdowns.length; a++) {
        paper_dropdowns[a].disabled = false;
        paper_dropdowns[a].querySelector('paper-input').disabled = false;
        paper_dropdowns[a].querySelector('paper-menu-button').disabled = false;
        paper_dropdowns[a].querySelector('iron-dropdown').disabled = false;
      }
    });
  },
  attached: function() { 
    if (this.hideIntercom) this.tryToHideIntercom();
  },

  // Computed Properties
  _currentUserProfile: function(currentUser) { return "/u/" + currentUser.username_with_caps; },
  _headerPanelClass: function(backgroundMode, colorMode) { 
    return colorMode + "-color " + backgroundMode + "-background "; 
  },
  _toolbarClass: function(backgroundMode, colorMode, toolbarMode, headerMode) { 
    return colorMode + "-color " + backgroundMode + "-background " + toolbarMode
      + ((headerMode == "condensable") ? " paper-header" : "");
  },
  _isAppbarMode_Standard: function(appbarMode) { return appbarMode == "standard"; },
  _isAppbarMode_Home: function(appbarMode) { return appbarMode == "home"; },
  _isHeaderMode_Condensable: function(headerMode) { return headerMode == "condensable"; },

  // Helpers
  tryToHideIntercom: function(tryCount) {
    var self = this;

    if (!tryCount) tryCount = 1;

    if (document.querySelector('#intercom-container'))
      document.querySelector('#intercom-container').hidden = true;
    else if (tryCount < 100)
      setTimeout(function() { self.tryToHideIntercom(tryCount + 1); }, 100);
  }
});
