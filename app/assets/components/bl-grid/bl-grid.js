Polymer({
  is: "bl-grid",

  properties: {
    // Required
    mode: String, // = ['badges', 'groups']
    nextPageUrl: String,
    nextPage: {
      type: Number,
      value: -1
    },
    
    // Optional
    options: Object,
    
    // Mode-specifid
    badges: {
      type: Array,
      value: function() {  return []; }
    },
    groups: {
      type: Array,
      value: function() {  return []; }
    },

    // Computed
    isBadgesMode: {
      type: Boolean,
      computed: "_isBadgesMode(mode)"
    },
    isGroupsMode: {
      type: Boolean,
      computed: "_isGroupsMode(mode)"
    },
    showPlaceholder: {
      type: Boolean,
      computed: "_showPlaceholder(mode, groups, badges)"
    },
    hasNextPage: {
      type: Boolean,
      computed: "_hasNextPage(nextPage)"
    }
  },

  // Events
  ready: function() {
    // this.customStyle["--item-background-color"] = "rgb(189,189,189)";
    // this.updateStyles();
  },

  // Computed Properties
  _isBadgesMode: function(mode) { return mode == "badges"; },
  _isGroupsMode: function(mode) { return mode == "groups"; },
  _showPlaceholder: function(mode, groups, badges) {
    if (mode == "groups") return groups.length == 0;
    else if (mode == "badges") return badges.length == 0;
    else return false;
  },
  _hasNextPage: function(nextPage) { return nextPage > 0; },

  // Helpers
  loadNextPage: function() {
    var nextPageButton = this.$$("#next-page-button");
    var self = this; // Hold onto the context variable
    
    if (!nextPageButton.disabled) {
      nextPageButton.disabled = true;

      $.getJSON(this.nextPageUrl + this.nextPage, function(result) {
        if (result) {
          // Add all of the new results to the array (this will auto update the dom-repeat)
          for (var i = 0; i <= result[self.mode].length; i++) 
            self.push(self.mode, result[self.mode][i]);
          
          // Store the new value of nextPage and re-enable the next page button
          self.nextPage = result.next_page;
          nextPageButton.disabled = false;
        }
      });
    }
  }
});
