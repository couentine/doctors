Polymer({
  is: 'bl-user-selector',

  properties: {
    users: { type: Array, observer: '_usersChanged' },
    groupTags: { // include any user-related tags with pending feedback requests
      type: Array, observer: '_groupTagsChanged' },
    groupTagsLink: String, // this controls the href of the "create group tags" placeholder text
    selectedTagName: { type: String, value: 'NONE' }, // default value of group tag dropdown
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
    hasGroupTags: { type: Boolean, value: false, computed: '_hasGroupTags(groupTags)' },
    hideCollapsedView: { type: Boolean, computed: '_hideCollapsedView(disabled, expanded)' },
    hideExpandedView: { type: Boolean, computed: '_hideExpandedView(disabled, expanded)' }
  },

  // Events
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
  groupTagFilterSelect: function(e) {
    if (this.$.groupTagFilter.selected == 'NONE')
      $('.user.select-link').show();
    else {
      // First hide everything, then show only the ones with the selected tag
      var selectedTagClass = 'tag-' + this.$.groupTagFilter.selected;
      $('.user.select-link').hide();
      $('.user.select-link.' + selectedTagClass).show();
    }
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
  _hasGroupTags: function(groupTags) { return groupTags && (groupTags.length > 0); },
  _hideCollapsedView: function(disabled, expanded) { return disabled || expanded; },
  _hideExpandedView: function(disabled, expanded) { return disabled || !expanded; },

  // Observers
  _usersChanged: function(newValue, oldValue) { this.updateUserItemClasses(); },
  _groupTagsChanged: function(newValue, oldValue) { this.updateUserItemClasses(); },
  _selectedUserUsernameChanged: function(newValue, oldValue) {
    var targetList;

    if (this.userUsernameMap) {
      this.selectedUser = this.userUsernameMap[newValue];
      this.refreshTargetListQuery();
    }
  },
  
  // Helpers
  updateUserItemClasses: function() {
    // This sets the classNames property to contain all of the tag names which contain this user 
    // plus the base classes. This is used to conditionally hide / show users based on tag.
    // Example classNames value: 'user select-link tag-exampletagname tag-another-tag'
    
    var userMap = {}; // user_id => user
    var baseClasses = 'user select-link';

    if (this.users && this.users.length) {
      // First build the user map and initialize the classNames
      for (var i = 0; i < this.users.length; i++) {
        this.users[i].classNames = baseClasses;
        userMap[this.users[i].id] = this.users[i];
      }

      // Then loop through the group tags (if needed) and add the tag-specific item classes
      if (this.groupTags)
        for (var i = 0; i < this.groupTags.length; i++)
          if (this.groupTags[i].user_id_strings)
            for (var j = 0; j < this.groupTags[i].user_id_strings.length; j++)
              if (userMap[this.groupTags[i].user_id_strings[j]])
                userMap[this.groupTags[i].user_id_strings[j]].classNames += ' tag-' 
                  + this.groupTags[i].name;
    }
  }

});