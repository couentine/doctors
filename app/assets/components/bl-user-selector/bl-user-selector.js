Polymer({
  is: 'bl-user-selector',

  properties: {
    users: Array,
    groupId: String, // used to pass to bl-user
    for: String, // id of the bl-list
    expandedParent: { type: String, value: 'body' }, // query selector for the parent element
    selectedUserUsername: { type: String, observer: '_selectedUserUsernameChanged' },
    selectedUser: Object,
    userUsernameMap: Object,
    disabled: { type: Boolean, value: false, notify: true },
    expanded: { type: Boolean, value: false, notify: true },
    
    // Computed Properties
    hasUsers: { type: Boolean, value: false, computed: '_hasUsers(users)' },
    hideCollapsedView: { type: Boolean, computed: '_hideCollapsedView(disabled, expanded)' },
    hideExpandedView: { type: Boolean, computed: '_hideExpandedView(disabled, expanded)' }
  },

  attached: function() {
    // Build userUsernameMap
    this.userUsernameMap = {};
    for (var i = 0; i < this.users.length; i++)
      this.userUsernameMap[this.users[i].username] = this.users[i];
    
    // Set the user if needed
    if (this.selectedUserUsername)
      this._selectedUserUsernameChanged(this.selectedUserUsername, null);

    // Now re-parent the expanded container
    if (document.querySelector(this.expandedParent))
      $(document.querySelector(this.expandedParent)).append(this.$['expanded-container']);
  },

  // Functions
  expand: function(e) { this.expanded = true; if (e) e.preventDefault(); },
  close: function(e) { this.expanded = false; if (e) e.preventDefault(); },
  selectThisUser: function(e) { 
    this.selectedUserUsername = $(e.target).closest('.select-link')[0].dataUserUsername;
    this.close();
    e.preventDefault();
  },
  refreshTargetListQuery: function() {
    // This will update the query options on the target list
    if (this.for) {
      targetList = document.querySelector('#' + this.for);
      // NOTE: We need to clear out the badge option because of the way this is being used
      // in the review screen. This may need to change once the element is used in other contexts
      if (targetList) 
        targetList.updateQueryOptions({ user: this.selectedUserUsername, badge: null });
    }
  },

  // Computed Properties
  _hasUsers: function(users) { return users && (users.length > 0); },
  _hideCollapsedView: function(disabled, expanded) { return disabled || expanded; },
  _hideExpandedView: function(disabled, expanded) { return disabled || !expanded; },

  // Observers
  _selectedUserUsernameChanged: function(newValue, oldValue) {
    var targetList;

    if (this.userUsernameMap) {
      this.selectedUser = this.userUsernameMap[newValue];
      this.refreshTargetListQuery();
    }
  }
});