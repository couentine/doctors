Polymer({
  is: 'bl-group-tag',

  properties: {
    groupTag: { type: Object, observer: '_groupTagObserver' },
    link: { type: Boolean, value: false },
    elevation: { type: Number, value: 0 },
    hoverElevation: { type: Number, value: 1 },

    // Read Only
    currentElevation: { type: Number, readOnly: true, value: 1 },
    hasGroupTag: { type: Boolean, readOnly: true, value: false }
  },

  listeners: {
    'paper.mouseover': 'paperMouseOver',
    'paper.mouseout': 'paperMouseOut'
  },

  // Events
  ready: function() { this._setCurrentElevation(this.elevation); },
  paperMouseOver: function() { this._setCurrentElevation(this.hoverElevation); },
  paperMouseOut: function() { this._setCurrentElevation(this.elevation); },
  
  // Events
  _groupTagObserver: function(newValue, oldValue) {
    this._setHasGroupTag(newValue && newValue.groupTagname_with_caps);
  }
});
