/* ================================================== */
/* ===================>> BL USER <<================== */
/* ================================================== */

/*
  
  This component displays a user card. It is typically used in conjuction with bl-list.

  ADMIN DISPLAY MODE
    If you set displayMode to 'admin' a remove button is included in the upper right corner of the
    card. Clicking that button will fire a 'bl-user-remove' event with e.detail.user = the user.

*/

Polymer({
  is: 'bl-user',

  properties: {
    user: { type: Object, observer: '_userObserver' },
    displayMode: String, // optional = ['admin']
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
    avatarUrl: { type: String, computed: '_avatarUrl(user)' },
    requestCount: { type: Number, computed: '_requestCount(user, groupId)' },
    showMetricList: { type: Boolean, computed: '_showMetricList(hasUser, showRequestCount)' },
    showRemove: { type: Boolean, computed: '_showRemove(displayMode)' }
  },

  listeners: {
    'paper.mouseover': 'paperMouseOver',
    'paper.mouseout': 'paperMouseOut'
  },

  // Observers
  _userObserver: function(newValue, oldValue) {
    this._setHasUser(newValue && newValue.username_with_caps);
  },

  // Events
  ready: function() { this._setCurrentElevation(this.elevation); },
  paperMouseOver: function() { this._setCurrentElevation(this.hoverElevation); },
  paperMouseOut: function() { this._setCurrentElevation(this.elevation); },
  removeUser: function(e) {
    e.preventDefault(); // This prevents the anchor tag from being followed
    this.fire('bl-user-remove', { user: this.user });
  },

  // Computed Properties
  _avatarUrl: function(user) {
    if (user && user.avatar_image_medium_url) return user.avatar_image_medium_url;
    else return "https://secure.gravatar.com/avatar/0?s=200&d=mm";
  },
  _requestCount: function(user, groupId) {
    if (user && user.group_validation_request_counts && groupId)
      return user.group_validation_request_counts[groupId];
    else
      return null;
  },
  _showMetricList: function(hasUser, showRequestCount) { 
    // This is in case in the future there are multiple metrics
    return hasUser && showRequestCount; 
  },
  _showRemove: function(displayMode) { return displayMode == 'admin';}
  
});
