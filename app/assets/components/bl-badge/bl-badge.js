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

    // Computed
    showMetricList: { type: Boolean, value: false, 
      computed: "_showMetricList(showExpertCount, showRequestCount)" },

    // Auto set
    badgeName: String,
    hasBadge: Boolean
  },

  ready: function() {
    this._badgeObserver();
  },

  // Computed Properties
  _showMetricList: function(showExpertCount, showRequestCount) {
    return showExpertCount || showRequestCount;
  },

  // Observers
  _badgeObserver: function() {
    if (this.badge) this.hasBadge = true;
    else this.hasBadge = false;

    if (this.badge && this.badge.name) this.badgeName = this.badge.name;
    else this.badgeName = this.blankBadgeText;
  }
});
