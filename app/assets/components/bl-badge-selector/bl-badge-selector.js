Polymer({
  is: 'bl-badge-selector',

  properties: {
    badges: Array,
    for: String, // id of the bl-list
    expandedParent: { type: String, value: 'body' }, // query selector for the parent element
    selectedBadgeUrl: { type: String, observer: '_selectedBadgeUrlChanged' },
    selectedBadge: Object,
    badgeUrlMap: Object,
    disabled: { type: Boolean, value: false, notify: true },
    expanded: { type: Boolean, value: false, notify: true },
    
    // Computed Properties
    hasBadges: { type: Boolean, value: false, computed: '_hasBadges(badges)' },
    hideCollapsedView: { type: Boolean, computed: '_hideCollapsedView(disabled, expanded)' },
    hideExpandedView: { type: Boolean, computed: '_hideExpandedView(disabled, expanded)' }
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
      $(document.querySelector(this.expandedParent)).append(this.$['expanded-container']);
  },

  // Functions
  expand: function(e) { this.expanded = true; if (e) e.preventDefault(); },
  close: function(e) { this.expanded = false; if (e) e.preventDefault(); },
  selectThisBadge: function(e) { 
    this.selectedBadgeUrl = $(e.target).closest('.select-link')[0].dataBadgeUrl;
    this.close();
    e.preventDefault();
  },
  refreshTargetListQuery: function() {
    // This will update the query options on the target list
    if (this.for) {
      targetList = document.querySelector('#' + this.for);
      // NOTE: We need to clear out the user option because of the way this is being used
      // in the review screen. This may need to change once the element is used in other contexts
      if (targetList) targetList.updateQueryOptions({ badge: this.selectedBadgeUrl, user: null });
    }
  },

  // Computed Properties
  _hasBadges: function(badges) { return badges && (badges.length > 0); },
  _hideCollapsedView: function(disabled, expanded) { return disabled || expanded; },
  _hideExpandedView: function(disabled, expanded) { return disabled || !expanded; },

  // Observers
  _selectedBadgeUrlChanged: function(newValue, oldValue) {
    var targetList;

    if (this.badgeUrlMap) {
      this.selectedBadge = this.badgeUrlMap[newValue];
      this.refreshTargetListQuery();
    }
  }
});
