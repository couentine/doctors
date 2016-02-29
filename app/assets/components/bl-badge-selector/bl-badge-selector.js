Polymer({
  is: "bl-badge-selector",

  properties: {
    badges: Array,
    selectedBadgeUrl: {
      type: String,
      observer: "_selectedBadgeUrlChanged"
    },
    hasBadges: {
      type: Boolean,
      value: false,
      computed: "_hasBadges(badges)"
    },
    selectedBadge: Object,
    badgeUrlMap: Object,
    expanded: {
      type: Boolean,
      value: false
    }
  },

  attached: function() {
    // Build badgeUrlMap
    this.badgeUrlMap = {};
    for (var i = 0; i < this.badges.length; i++)
      this.badgeUrlMap[this.badges[i].url] = this.badges[i];
  },

  // Functions
  expand: function(e) { this.expanded = true; if (e) e.preventDefault(); },
  close: function(e) { this.expanded = false; if (e) e.preventDefault(); },
  selectThisBadge: function(e) { 
    this.selectedBadgeUrl = $(e.srcElement).closest(".select-link")[0].dataBadgeUrl;
    this.close();
  },

  // Computed Properties
  _hasBadges: function(badges) { return badges && (badges.length > 0); },

  // Observers
  _selectedBadgeUrlChanged: function(newValue, oldValue) {
    if (this.badgeUrlMap)
      this.selectedBadge = this.badgeUrlMap[newValue];
  }
});
