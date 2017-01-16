Polymer({
  is: "bl-app-container",

  properties: {
    // Required
    assetPaths: { type: Object },
    currentUser: { type: Object },
    
    // Optional
    pageBackground: { type: String, value:'#FFFFFF', observer:'_pageBackgroundChanged' },
    whiteHeaderText: { type: Boolean, value: false },
    whiteBodyText: { type: Boolean, value: false },
    hideCondensedHeader: { type: Boolean, value: false }, // Scroll away header after condensing
    hideLeftNav: { type: Boolean, value: false },
    hideRightNav: { type: Boolean, value: false },
    hideIntercom: { type: Boolean, value: false },
    
    // Automatically Set
    condensedHeaderHeightEm: { type: Number, value: 3 }, // set from child app header element
    screenWidth: { type: Number, readOnly: true },

    // Computed
    condensedHeaderHeightPx: { type: Number, 
      computed: '_condensedHeaderHeightPx(condensedHeaderHeightEm, screenWidth)' },

    // Font Size Contant (Maps from screenWidth to fontSize)
    fontSizeBreakpoints: { type: Array, value: function() { return [
      { minWidth: 0, fontSize: 14 },
      { minWidth: 480, fontSize: 16 },
      { minWidth: 840, fontSize: 18 }
    ]; } }
  },

  // Listeners
  listeners: {
    'headerPanel.paper-header-transform': '_headerPanelTransform',
    'bl-app-header-content-ready': '_appHeaderContentReady'
  },
  _headerPanelTransform: function(e) {
    var detail = e.detail; // detail keys = [condensedHeight, height, y]
    var y = detail.y;

    // Move the navbars down to accomodate the condensed space
    var newY = (y === null) ? null : Math.min(y, detail.height - detail.condensedHeight);
    this.transform((newY === null) ? '' : 'translate3d(0, ' + newY + 'px, 0)', this.$.leftNav);
    this.transform((newY === null) ? '' : 'translate3d(0, ' + newY + 'px, 0)', this.$.rightNav);

    // If header is condensed then add the shadow, otherwise remove it
    if (this.$.headerPanel.headerState == Polymer.PaperScrollHeaderPanel.HEADER_STATE_CONDENSED)
      $(this.$.appHeader).addClass('elevated');
    else
      $(this.$.appHeader).removeClass('elevated');
  },
  _appHeaderContentReady: function(e) {
    // Pull the condensed header from the bl-app-header-* element
    this.condensedHeaderHeightEm = e.detail.condensedHeightEm;
  },

  // Events
  ready: function() {
    // We need to manually fix any paper drowndown menus if present
    // Details here: https://github.com/PolymerElements/paper-dropdown-menu/issues/10
    // NOTE: This doesn't seem to work in a normal listener
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
    // Update the screenWidth property anytime the window is resized
    var self = this;
    $(window).on('resize', function() { 
      self._setScreenWidth($(window).width()); 
    });
    self._setScreenWidth($(window).width()); // set it on page load as well

    if (this.hideIntercom) this.tryToHideIntercom();
  },

  // Observers
  _pageBackgroundChanged: function(newValue, oldValue) {
    // Update the css variable that controls background any time the value changes
    this.customStyle['--page-background'] = newValue;
    this.updateStyles();
  },

  // Computed Properties
  _condensedHeaderHeightPx: function(condensedHeaderHeightEm, screenWidth) {
    return this.fontSizeForScreenWidth(screenWidth) * condensedHeaderHeightEm;
  },

  // Helpers
  fontSizeForScreenWidth: function(screenWidth) {
    // Returns integer value of font size in pixels for the specified screen width
    // Refers to fontSizeBreakpoints

    var returnValue = 14; // default value is 14 if breakpoints haven't been loaded yet
    var breakpoints = this.fontSizeBreakpoints; // shortcut for code brevity

    if (breakpoints && breakpoints.length)
      for (var i=0; (i < breakpoints.length) && (screenWidth >= breakpoints[i].minWidth); i++)
        returnValue = breakpoints[i].fontSize;
    
    return returnValue;
  },
  tryToHideIntercom: function(tryCount) {
    var self = this;

    if (!tryCount) tryCount = 1;

    if (document.querySelector('#intercom-container'))
      document.querySelector('#intercom-container').hidden = true;
    else if (tryCount < 100)
      setTimeout(function() { self.tryToHideIntercom(tryCount + 1); }, 100);
  }
});
