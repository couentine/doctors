Polymer({
  is: "bl-badge",

  properties: {
    badge: {
      type: Object,
      observer: "_badgeObserver"
    },
    blankBadgeText: {
      type: String,
      value: "No Badge"
    },
    blankBadgeIconClass: {
      type: String,
      value: "fa fa-ban"
    },

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
  }
});
