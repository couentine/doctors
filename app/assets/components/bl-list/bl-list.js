/* ================================================== */
/* =============>> BL LIST COMPONENT <<============== */
/* ================================================== */

/*
  This is the generic list component.  It is designed to present a list of objects (specified by 
  objectMode). The layout and styling is automatically determined by the objectMode. You can
  either provide the first page of objects directly to the items property or leave it blank and 
  have it be queried later. If you leave items blank then set queryOnDisplay to have the component
  automatically query the first page of results whenever the component is displayed. Otherwise
  you will need to manually query using one of the query methods.

  The next page button will only be displayed if nextPage is greater than 0. The new nextPage
  value is then pulled form the "next_page" key of the returned result.

  The URL for next page queries is: "{nextPageUrl}&{nextPageParam}={nextPage}&{queryOptions...}"
*/

Polymer({
  is: "bl-list",

  properties: {
    // Required
    objectMode: String, // = ['badges', 'full_logs', 'groups']
    nextPageUrl: String, // and ampersand + next page and query options are appended to this
    nextPage: { type: Number, value: 1 },
    nextPageParam: {
      type: String,
      value: "page"
    },
    
    // Options
    queryOptions: Object, // Added to next page query: "&key1=value1&key2=value2" ...
    options: Object,
    queryOnDisplay: { // NOTE: This doesn't work yet.
      type: Boolean,
      value: false
    },
    
    // The object items
    items: Array,

    // Computed
    layoutMode: { type: String, computed: "_layoutMode(objectMode)" },
    itemClass: { type: String, computed: "_itemClass(layoutMode, objectMode)" },
    wrapperClass: { type: String, computed: "_wrapperClass(layoutMode, objectMode)" },
    hasNextPage: { 
      type: Boolean, 
      value: false,
      computed: "_hasNextPage(nextPage, items)" 
    },
    showPlaceholder: {
      type: Boolean,
      false: false,
      computed: "_showPlaceholder(items)"
    }
  },

  // Methods
  queryNextPage: function () {
    // Queries for the next page and APPENDS the results to the display, then increments nextPage.
    var nextPageButton = this.$$("#next-page-button");
    var self = this; // Hold onto the context variable
    
    if (!nextPageButton.disabled) {
      nextPageButton.disabled = true;

      this.getResults(function(result) {
        if (result) {
          // Add all of the new results to the array (this will auto update the dom-repeat)
          for (var i = 0; i <= result[self.objectMode].length; i++) 
            self.push('items', result[self.objectMode][i]);
          
          // Store the new value of nextPage and re-enable the next page button
          self.nextPage = result.next_page;
          nextPageButton.disabled = false;
        }
      }, function() {
        console.log('An error occurred while trying to retrieve the next page of results.');
      });
    }
  },
  refreshQuery: function () {
    // Resets nextPage to 1, then queries for the next page and REPLACES the existing results.

    // Queries for the next page and APPENDS the results to the display, then increments nextPage.
    var nextPageButton = this.$$("#next-page-button");
    var self = this; // Hold onto the context variable
    
    nextPageButton.disabled = true;
    self.nextPage = 1;
    while(self.pop('items')) {} // clear out the existing items

    this.getResults(function(result) {
      if (result) {
        // Add all of the new results to the array (this will auto update the dom-repeat)
        for (var i = 0; i <= result[self.objectMode].length; i++) 
          self.push('items', result[self.objectMode][i]);
        
        // Store the new value of nextPage and re-enable the next page button
        self.nextPage = result.next_page;
        nextPageButton.disabled = false;
      }
    }, function() {
      console.log('An error occurred while trying to retrieve results.');
    });
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
  _hasNextPage: function(nextPage, items) { return items && (nextPage > 0); },

  // Helpers
  getFullUrl: function() {
    var fullUrl = this.nextPageUrl;
    var queryOptions = this.queryOptions; // we can't access the 'this' variable inside the loop

    // First add the page parameter (along with a question mark to the url if it's missing)
    fullUrl += (fullUrl.includes("?")) ? "&" : "?";
    fullUrl += this.nextPageParam + "=" + this.nextPage;

    if (queryOptions)
      Object.keys(queryOptions).forEach(function(key, index) {
        fullUrl += "&" + key + "=" + queryOptions[key];
      });

    return fullUrl;
  },
  // Queries next page & runs either completeFunction(results) or errorFunction()
  getResults: function(completeFunction, errorFunction) { 
    $.getJSON(this.getFullUrl(), function(result) {
      if (result) completeFunction(result);
      else errorFunction();
    });
  }
});