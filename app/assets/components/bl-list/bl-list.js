Polymer({
  is: "bl-list",

  properties: {
    // Required
    objectMode: String, // = ['badges', 'full_logs', 'groups']
    nextPageUrl: String,
    nextPage: { type: Number, value: -1 },
    
    // Optional
    options: Object,
    
    // Mode-specifid
    items: { type: Array, value: function() { return []; } },

    // Computed
    layoutMode: { type: String, computed: "_layoutMode(objectMode)" },
    itemClass: { type: String, computed: "_itemClass(layoutMode, objectMode)" },
    wrapperClass: { type: String, computed: "_wrapperClass(layoutMode, objectMode)" },
    hasNextPage: { type: Boolean, computed: "_hasNextPage(nextPage)" },
    showPlaceholder: {
      type: Boolean,
      computed: "_showPlaceholder(items)"
    }
  },

  // Computed Properties
  _layoutMode: function(objectMode) {
    switch (objectMode) {
      case "badges": return "grid"; break;
      case "full_logs": return "column"; break;
      case "groups": return "grid"; break;
    }
  },
  _itemClass: function(layoutMode, objectMode) { return layoutMode + "-item " + objectMode; },
  _wrapperClass: function(layoutMode, objectMode) { return layoutMode + "-list " + objectMode; },
  _showPlaceholder: function(items) {
    return items && (items.length == 0);
  },
  _hasNextPage: function(nextPage) { return nextPage > 0; },

  // Helpers
  loadNextPage: function() {
    var nextPageButton = this.$$("#next-page-button")
    var self = this; // Hold onto the context variable
    
    if (!nextPageButton.disabled) {
      nextPageButton.disabled = true;

      $.getJSON(this.nextPageUrl + this.nextPage, function(result) {
        if (result) {
          // Add all of the new results to the array (this will auto update the dom-repeat)
          for (var i = 0; i <= result[self.objectMode].length; i++) 
            self.push('items', result[self.objectMode][i]);
          
          // Store the new value of nextPage and re-enable the next page button
          self.nextPage = result.next_page;
          nextPageButton.disabled = false;
        }
      });
    }
  }
});