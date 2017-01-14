Polymer({
  is: "bl-app-header-text",

  properties: {
    title: { type: String }, // Required: The page title
    subtitle: { type: String }, // Optional
    background: { type: String, value:'#FFFFFF', observer:'_backgroundChanged' },
    condensedBackground: { type: String, value:'#FB8C00', observer:'_condensedBackgroundChanged' },
    topLineColor: { type: String, value:'#FB8C00', observer:'_topLineColorChanged' },
    whiteText: { type: Boolean, value: false },

    // Left Nav Options (Leave blank for no custom left nav)
    leftNavSymbol: { type: String }, // set to a FULL font awesome code (ex: 'fa fa-arrow-left')
    
    // Computed Properties
    hasCustomLeftNav: { type: Boolean, computed: '_hasCustomLeftNav(leftNavSymbol)' },
    hasSubtitle: { type: Boolean, computed: '_hasSubtitle(subtitle)' },

    condensedHeightEm: { type: Number, value: 3.3, readOnly: true } // used by bl-app-container
  },

  // Listeners
  _headerPanelTransform: function(e) {
    var detail = e.detail; // detail keys = [condensedHeight, height, y]
    var y = detail.y;

    // Move the top line and left nav down to accomodate the condensed space
    var newY = (y === null) ? null : Math.min(y, detail.height - detail.condensedHeight);
    this.transform((newY === null) ? '' : 'translate3d(0, ' + newY + 'px, 0)', this.$.topLine);
    this.transform((newY === null) ? '' : 'translate3d(0, ' + newY + 'px, 0)', this.$.leftNav);

    // Update the opacity of the condensed background if needed
    var condensedPercentage = newY / (detail.height - detail.condensedHeight);
    this.$.condensedBackgroundPanel.style.opacity = condensedPercentage;

    // Update the size of the title and subtitle of the condensed background if needed
    var titleScale = 0.75 + (0.25*(1 - condensedPercentage));
    var subtitleFontSize = (1 - condensedPercentage);
    var subtitleHeight = subtitleFontSize * 1.5;
    this.transform('scale(' + titleScale + ') translateZ(0)', this.$.title);
    this.$.subtitle.style.fontSize = subtitleFontSize + 'em';
    this.$.subtitle.style.height = subtitleHeight + 'em';
    this.$.subtitle.style.opacity = subtitleFontSize;
  },
  _leftNavLinkTap: function(e) {
    console.log('In here');
    window.history.back();
    e.preventDefault();
  },

  // Events
  attached: function() {
    // Listen for the transform event
    var self = this;
    document.addEventListener('paper-header-transform', function(e) {
      self._headerPanelTransform(e);
    });
  },
  ready: function() {
    // Notify bl-app-container of the condensedHeaderHeight
    this.fire('bl-app-header-content-ready', { condensedHeightEm: this.condensedHeightEm });
  },

  // Observers
  _backgroundChanged: function(newValue, oldValue) {
    // Update the css variable that controls background any time the value changes
    this.customStyle['--background'] = newValue;
    this.updateStyles();
  },
  _condensedBackgroundChanged: function(newValue, oldValue) {
    // Update the css variable that controls background any time the value changes
    this.customStyle['--condensed-background'] = newValue;
    this.updateStyles();
  },
  _topLineColorChanged: function(newValue, oldValue) {
    // Update the css variable that controls background any time the value changes
    this.customStyle['--top-line-color'] = newValue;
    this.updateStyles();
  },

  // Property Computers
  _hasCustomLeftNav: function(leftNavSymbol) {
    return (leftNavSymbol && (leftNavSymbol.length > 0));
  },
  _hasSubtitle: function(subtitle) {
    return (subtitle && (subtitle.length > 0));
  }

});
