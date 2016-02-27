Polymer({
  is: "bl-badge-selector",

  properties: {
    badgeSets: Array,
    badgeSetLabels: Array,
    selectedBadgeId: String,

    // Computed
    expanded: {
      type: Boolean,
      default: false
    }
  },

  ready: function() {
    if (!this.selectedBadgeId) expanded = true;
  },

  // Computed Properties
  
});
