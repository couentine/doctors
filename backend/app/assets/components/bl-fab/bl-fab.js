Polymer({
  is: "bl-fab",

  properties: {
    // Required
    icon: String,
    
    // Optional
    background: { type: String, observer: '_backgroundChanged' }, // sets --paper-fab-background
    color: { type: String, observer: '_colorChanged' }, // sets text color
    link: String,
    target: String,
    tooltip: { type: String, observer: '_tooltipChanged' },

    // Set automatically
    hasTooltip: { type: Boolean, value: false, readOnly: true }
  },

  // Observers
  _backgroundChanged: function(newValue, oldValue) {
    // Update the css variable that controls background any time the value changes
    this.customStyle['--background'] = newValue;
    this.updateStyles();
  },
  _colorChanged: function(newValue, oldValue) {
    // Update the css variable that controls background any time the value changes
    this.customStyle['--color'] = newValue;
    this.updateStyles();
  },
  _tooltipChanged: function(newValue, oldValue) {
    this._setHasTooltip((newValue != null) && (newValue != undefined) && (newValue != ''));
  },

  // Events
  attached: function() {
    // Force update of color properties
    this.updateStyles();
  }
});
