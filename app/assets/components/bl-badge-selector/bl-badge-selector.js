Polymer({
  is: "bl-badge-selector",

  properties: {
    badges: Array,
    for: String, // id of the bl-list
    expandedParent: { type: String, value: "body" }, // query selector for the parent element
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
    
    // Set the badge if needed
    if (this.selectedBadgeUrl)
      this._selectedBadgeUrlChanged(this.selectedBadgeUrl, null);

    // Now re-parent the expanded container
    if (document.querySelector(this.expandedParent))
      $(document.querySelector(this.expandedParent)).append(this.$["expanded-container"]);
  },

  // Functions
  expand: function(e) { 
    this.expanded = true; if (e) e.preventDefault(); 
    document.querySelector("paper-scroll-header-panel").measureHeaderHeight();
  },
  close: function(e) { 
    this.expanded = false; if (e) e.preventDefault(); 
    document.querySelector("paper-scroll-header-panel").measureHeaderHeight();
  },
  selectThisBadge: function(e) { 
    this.selectedBadgeUrl = $(e.target).closest(".select-link")[0].dataBadgeUrl;
    this.close();
  },

  // Computed Properties
  _hasBadges: function(badges) { return badges && (badges.length > 0); },

  // Observers
  _selectedBadgeUrlChanged: function(newValue, oldValue) {
    var targetList;

    if (this.badgeUrlMap) {
      this.selectedBadge = this.badgeUrlMap[newValue];
      if (this.for) {
        targetList = document.querySelector("#" + this.for);
        if (targetList)
          targetList.updateQueryOptions({ "badge": newValue });
      }
    }
  }
});
