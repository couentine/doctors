Polymer({
  is: "bl-button",

  properties: {
    // Required
    type: String,
    
    // Optional
    disabled: { type: Boolean, reflectToAttribute: true, notify: true },
    link: String,
    target: String,
    background: { type: String, observer:'_backgroundChanged' },
    color: { type: String, observer:'_colorChanged' },

    // Computed
    isRaised: { type: String, computed: "_isRaised(type)" }
  },

  // Observers
  _backgroundChanged: function(newValue, oldValue) {
    // Update the css variable that controls background any time the value changes
    this.customStyle['--background'] = newValue;
    this.updateStyles();
  },
  _colorChanged: function(newValue, oldValue) {
    // Update the css variable that controls color any time the value changes
    this.customStyle['--color'] = newValue;
    this.updateStyles();
  },

  // Computed
  _isRaised: function(type) {
    return type == "raised";
  }
});
