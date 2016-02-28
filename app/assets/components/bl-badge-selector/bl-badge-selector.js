Polymer({
  is: "bl-badge-selector",

  properties: {
    badgeSets: Array,
    badgeSetLabels: Array,
    selectedBadgeSetIndex: {
      type: Number,
      value: 0
    },
    selectedBadgeUrl: {
      type: String,
      observer: "_selectedBadgeUrlChanged"
    },
    selectedBadge: Object,
    badgeUrlMap: Object,
    expanded: {
      type: Boolean,
      value: false
    }
  },

  attached: function() {
    var badgeSetCounts = [];
    var firstNonEmptyBadgeSetIndex = null;
    this.badgeUrlMap = {};

    // Show the placeholder if a tab is empty and figure out which tab to default to
    for (var i = 0; i < this.badgeSets.length; i++) {
      badgeSetCounts[i] = this.badgeSets[i].length;
      
      if (badgeSetCounts[i] == 0)
        document.querySelectorAll('.badge-grid .placeholder')[i].hidden = false;
      if ((badgeSetCounts[i] > 0) && (firstNonEmptyBadgeSetIndex == null))
        firstNonEmptyBadgeSetIndex = i;

      // Now build the badge url map
      for (var j = 0; j < badgeSetCounts[i]; j++)
        this.badgeUrlMap[this.badgeSets[i][j].url] = this.badgeSets[i][j];
    }

    // Override the selected tab if it is empty and there is another non-empty tab to show
    if ((badgeSetCounts[this.selectedBadgeSetIndex] == 0) && (firstNonEmptyBadgeSetIndex != null))
      this.selectedBadgeSetIndex = firstNonEmptyBadgeSetIndex;
  },

  // Functions
  expand: function(e) { this.expanded = true; if (e) e.preventDefault(); },
  close: function(e) { this.expanded = false; if (e) e.preventDefault(); },
  selectThisBadge: function(e) { 
    this.selectedBadgeUrl = $(e.srcElement).closest(".select-link")[0].dataBadgeUrl;
    this.close();
  },

  // Observers
  _selectedBadgeUrlChanged: function(newValue, oldValue) {
    if (this.badgeUrlMap)
      this.selectedBadge = this.badgeUrlMap[newValue];
  }
});
