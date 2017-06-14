/* ================================================== */
/* ==================>> BL BADGE <<================== */
/* ================================================== */

/*
  
  This component displays a badge card. It is typically used in conjuction with bl-list.

  ADMIN DISPLAY MODE
    If you set displayMode to 'admin' a remove button is included in the upper right corner of the
    card. Clicking that button will fire a 'bl-badge-remove' event with e.detail.badge = the badge.

*/

Polymer({
  is: "bl-badge",

  properties: {
    badge: { type: Object, observer: "_badgeObserver" },
    blankBadgeText: { type: String, value: "No Badge" },
    blankBadgeIconClass: { type: String, value: "fa fa-ban" },
    link: { type: Boolean, value: false },
    options: Object, // valid keys = showExpertCount, showRequestCount
    showExpertCount: { type: Boolean, value: false },
    showRequestCount: { type: Boolean, value: false },
    displayMode: String, // optional = ['admin']

    // Computed
    showMetricList: { type: Boolean, value: false, 
      computed: "_showMetricList(showExpertCount, showRequestCount)" },
    showRemove: { type: Boolean, computed: '_showRemove(displayMode)' },

    // Auto set
    badgeName: String,
    hasBadge: Boolean
  },

  ready: function() {
    this._badgeObserver();
  },

  // Observers
  _badgeObserver: function() {
    if (this.badge) this.hasBadge = true;
    else this.hasBadge = false;

    if (this.badge && this.badge.name) this.badgeName = this.badge.name;
    else this.badgeName = this.blankBadgeText;
  },

  // Events
  removeBadge: function(e) {
    e.preventDefault(); // This prevents the anchor tag from being followed
    this.fire('bl-badge-remove', { badge: this.badge });
  },

  // Computed Properties
  _showMetricList: function(showExpertCount, showRequestCount) {
    return showExpertCount || showRequestCount;
  },
  _showRemove: function(displayMode) { return displayMode == 'admin';}
});
