Polymer({
  is: 'bl-group-tag',

  properties: {
    groupTag: { type: Object, observer: '_groupTagObserver' },
    groupPath: String, // REQUIRED if link is true, example vaue: '/Group-Name'
    link: { type: Boolean, value: false },
    elevation: { type: Number, value: 0 },
    hoverElevation: { type: Number, value: 1 },

    // Computed
    linkPath: { type: String, computed: '_linkPath(groupPath, groupTag)' },

    // Read Only
    currentElevation: { type: Number, readOnly: true, value: 1 },
    hasGroupTag: { type: Boolean, readOnly: true, value: false }
  },

  listeners: {
    'paper.mouseover': 'paperMouseOver',
    'paper.mouseout': 'paperMouseOut'
  },

  // Observers
  _groupTagObserver: function(newValue, oldValue) {
    this._setHasGroupTag(newValue && newValue.groupTagname_with_caps);
  },

  // Events
  ready: function() { this._setCurrentElevation(this.elevation); },
  paperMouseOver: function() { this._setCurrentElevation(this.hoverElevation); },
  paperMouseOut: function() { this._setCurrentElevation(this.elevation); },

  // Computers
  _linkPath: function(groupPath, groupTag) {
    return groupPath + '/tags/' + groupTag.name_with_caps;
  }
  
});
