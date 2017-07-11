Polymer({
  is: 'bl-badge-selector',

  properties: {
    badges: Array,
    groupTags: { // include any badge-related tags with pending feedback requests
      type: Array, observer: '_groupTagsChanged' },
    groupTagsLink: String, // this controls the href of the "create group tags" placeholder text
    selectedTagName: { type: String, value: 'NONE' }, // default value of group tag dropdown
    for: String, // id of the bl-list
    expandedParent: { type: String, value: 'body' }, // query selector for the parent element
    selectedBadgeUrl: { type: String, observer: '_selectedBadgeUrlChanged' },
    selectedBadge: Object,
    badgeUrlMap: Object,
    disabled: { type: Boolean, value: false, notify: true },
    expanded: { type: Boolean, value: false, notify: true },
    
    // Computed Properties
    hasBadges: { type: Boolean, value: false, computed: '_hasBadges(badges)' },
    hasGroupTags: { type: Boolean, value: false, computed: '_hasGroupTags(groupTags)' },
    hideCollapsedView: { type: Boolean, computed: '_hideCollapsedView(disabled, expanded)' },
    hideExpandedView: { type: Boolean, computed: '_hideExpandedView(disabled, expanded)' }
  },

  // Events
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
  groupTagFilterSelect: function(e) {
    if (this.$.groupTagFilter.selected == 'NONE')
      $('.badge.select-link').show();
    else {
      // First hide everything, then show only the ones with the selected tag
      var selectedTagClass = 'tag-' + this.$.groupTagFilter.selected;
      $('.badge.select-link').hide();
      $('.badge.select-link.' + selectedTagClass).show();
    }
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
  _hasGroupTags: function(groupTags) { return groupTags && (groupTags.length > 0); },
  _hideCollapsedView: function(disabled, expanded) { return disabled || expanded; },
  _hideExpandedView: function(disabled, expanded) { return disabled || !expanded; },

  // Observers
  _selectedBadgeUrlChanged: function(newValue, oldValue) {
    var targetList;

    if (this.badgeUrlMap) {
      this.selectedBadge = this.badgeUrlMap[newValue];
      this.refreshTargetListQuery();
    }
  },
  _groupTagsChanged: function(newValue, oldValue) { this.updateBadgeItemClasses(); },

  // Helpers
  updateBadgeItemClasses: function() {
    // This sets the classNames property to contain all of the tag names which contain this badge 
    // plus the base classes. This is used to conditionally hide / show badges based on tag.
    // Example classNames value: 'badge select-link tag-exampletagname tag-another-tag'
    
    var badgeMap = {}; // badge_id => badge
    var baseClasses = 'badge select-link';

    if (this.badges && this.badges.length) {
      // First build the badge map and initialize the classNames
      for (var i = 0; i < this.badges.length; i++) {
        this.badges[i].classNames = baseClasses;
        badgeMap[this.badges[i].id] = this.badges[i];
      }

      // Then loop through the group tags (if needed) and add the tag-specific item classes
      if (this.groupTags)
        for (var i = 0; i < this.groupTags.length; i++)
          if (this.groupTags[i].badge_id_strings)
            for (var j = 0; j < this.groupTags[i].badge_id_strings.length; j++)
              if (badgeMap[this.groupTags[i].badge_id_strings[j]])
                badgeMap[this.groupTags[i].badge_id_strings[j]].classNames += ' tag-' 
                  + this.groupTags[i].name;
    }
  }
});
