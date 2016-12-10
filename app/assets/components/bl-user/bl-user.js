Polymer({
  is: 'bl-user',

  properties: {
    user: { type: Object, observer: '_userObserver' },
    groupId: String, // used to extract appropriate request count from user
    blankUserText: { type: String, value: 'Nobody' },
    blankUserIconClass: { type: String, value: 'fa fa-fw fa-user' },
    link: { type: Boolean, value: false },
    elevation: { type: Number, value: 1 },
    hoverElevation: { type: Number, value: 3 },
    showRequestCount: { type: Boolean, value: false },

    // Read Only
    currentElevation: { type: Number, readOnly: true, value: 1 },
    hasUser: { type: Boolean, readOnly: true, value: false },
    
    // Computed
    requestCount: { type: Number, computed: '_requestCount(user, groupId)' },
    showMetricList: { type: Boolean, computed: '_showMetricList(hasUser, showRequestCount)' }
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
  _userObserver: function(newValue, oldValue) {
    this._setHasUser(newValue && newValue.username_with_caps);
  },

  // Computed Properties
  _requestCount: function(user, groupId) {
    if (user && user.group_validation_request_counts && groupId)
      return user.group_validation_request_counts[groupId];
    else
      return null;
  },
  _showMetricList: function(hasUser, showRequestCount) { 
    // This is in case in the future there are multiple metrics
    return hasUser && showRequestCount; 
  }
  
});
