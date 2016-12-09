Polymer({
  is: 'bl-user',

  properties: {
    user: { type: Object, value: function() { return {}; } },
    groupId: String, // used to extract appropriate request count from user
    blankUserText: { type: String, value: 'Nobody' },
    blankUserIconClass: { type: String, value: 'fa fa-ban' },
    link: { type: Boolean, value: false },
    showRequestCount: { type: Boolean, value: false },

    // Computed
    hasUser: { type: Boolean, computed: '_hasUser(user)' },
    requestCount: { type: Number, computed: '_requestCount(user, groupId)' },
    showMetricList: { type: Boolean, computed: '_showMetricList(showRequestCount)' }
  },

  listeners: {
    'paper.mouseover': 'paperMouseOver',
    'paper.mouseout': 'paperMouseOut'
  },

  // Events
  ready: function() {
    // this.notifyPath('user');
  },
  paperMouseOver: function() {
    this.$.paper.elevation = 3;
  },
  paperMouseOut: function() {
    this.$.paper.elevation = 0;
  },

  // Computed Properties
  _hasUser: function(user) { return user && user.username_with_caps; },
  _requestCount: function(user, groupId) {
    if (user && user.group_validation_request_counts && groupId)
      return user.group_validation_request_counts[groupId];
    else
      return null;
  },
  _showMetricList: function(showRequestCount) { 
    // This is in case in the future there are multiple metrics
    return showRequestCount; 
  }
  
});
