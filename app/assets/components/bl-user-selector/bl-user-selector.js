Polymer({
  is: 'bl-user-selector',

  properties: {
    users: Array,
    for: String, // id of the bl-list
    expandedParent: { type: String, value: 'body' }, // query selector for the parent element
    selectedUserUsername: { type: String, observer: '_selectedUserUsernameChanged' },
    selectedUser: Object,
    userUsernameMap: Object,
    expanded: { type: Boolean, value: false },
    hidden: { type: Boolean, value: false },

    // Computed Properties
    hasUsers: { type: Boolean, value: false, computed: '_hasUsers(users)' },
    hideCollapsedView: { type: Boolean, computed: '_hideCollapsedView(expanded, hidden)' },
    hideExpandedView: { type: Boolean, computed: '_hideExpandedView(expanded, hidden)' }
  },

  attached: function() {
    // Build userUsernameMap
    this.userUsernameMap = {};
    for (var i = 0; i < this.users.length; i++)
      this.userUsernameMap[this.users[i].url] = this.users[i];
    
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
  show: function(e) { this.hidden = false; this.expand(); if (e) e.preventDefault(); },
  hide: function(e) { this.close(); this.hidden = true; if (e) e.preventDefault(); },
  selectThisUser: function(e) { 
    this.selectedUserUsername = $(e.target).closest('.select-link')[0].dataUserUsername;
    this.close();
  },

  // Computed Properties
  _hasUsers: function(users) { return users && (users.length > 0); },
  _hideCollapsedView: function(expanded, hidden) { return expanded || hidden; },
  _hideExpandedView: function(expanded, hidden) { return !expanded || hidden; },

  // Observers
  _selectedUserUsernameChanged: function(newValue, oldValue) {
    var targetList;

    if (this.userUsernameMap) {
      this.selectedUser = this.userUsernameMap[newValue];
      if (this.for) {
        targetList = document.querySelector('#' + this.for);
        if (targetList)
          targetList.updateQueryOptions({ 'user': newValue });
      }
    }
  }
});
