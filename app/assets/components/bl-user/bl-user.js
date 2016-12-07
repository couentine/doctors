Polymer({
  is: "bl-badge",

  properties: {
    badge: { type: Object, observer: "_badgeObserver" },
    blankBadgeText: { type: String, value: "No Badge" },
    blankBadgeIconClass: { type: String, value: "fa fa-ban" },
    link: { type: Boolean, value: false },
    options: Object, // valid keys = showExpertCount, showRequestCount

    // Computed
    showMetricList: { type: Boolean, value: false, computed: "_showMetricList(options)" },
    showExpertCount: { type: Boolean, value: false, computed: "_showExpertCount(options)" },
    showRequestCount: { type: Boolean, value: false, computed: "_showRequestCount(options)" },

    // Auto set
    badgeName: String,
    hasBadge: Boolean
  },

  ready: function() {
    this._badgeObserver();
  },

  // Computed Properties
  _showMetricList: function(options) {
    return options && (options.showExpertCount || options.showRequestCount)
  },
  _showExpertCount: function(options) { return options && options.showExpertCount; },
  _showRequestCount: function(options) { return options && options.showRequestCount; },

  // Observers
  _badgeObserver: function() {
    if (this.badge) this.hasBadge = true;
    else this.hasBadge = false;

    if (this.badge && this.badge.name) this.badgeName = this.badge.name;
    else this.badgeName = this.blankBadgeText;
  }
});
