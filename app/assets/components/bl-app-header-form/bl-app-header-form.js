Polymer({
  is: "bl-app-header-form",

  properties: {
    title: { type: String }, // Required: The page title
    background: { type: String, observer:'_backgroundChanged' },
    condensedBackground: { type: String, observer:'_condensedBackgroundChanged' },
    
    condensedHeightEm: { type: Number, value: 5, readOnly: true } // used by bl-app-container
  },

  // Listeners
  _headerPanelTransform: function(e) {
    var detail = e.detail; // detail keys = [condensedHeight, height, y]
    var y = detail.y;

    // Update the opacity of the condensed background if needed
    var newY = (y === null) ? null : Math.min(y, detail.height - detail.condensedHeight);
    var condensedPercentage = newY / (detail.height - detail.condensedHeight);    
    this.$.condensedBackgroundPanel.style.opacity = condensedPercentage;

    // Change the title color if needed
    if (condensedPercentage == 1.0) this.$.title.style.color = 'white';
    else this.$.title.style.color = '#616161';
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
  _condensedBackgroundChanged: function(newValue, oldValue) {
    // Update the css variable that controls background any time the value changes
    this.customStyle['--condensed-background'] = newValue;
    this.updateStyles();
  }
});
