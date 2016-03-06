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
    refreshQueryOnDisplay: {
      type: Boolean,
      value: false
    },
    selectionBar: Object, // this gets set by the bl-selection-bar when the "for" property is set
    
    // The object items
    items: Array,
    itemsLoaded: { type: Boolean, value: false }, // set automatically
    selectedItems: { type: Array, value: function() { return []; } },
    selectedItemCount: { type: Number, value: 0, computed: "_selectedItemCount(selectedItems)",
      observer: "_selectedItemCountChanged" },

    // Computed
    layoutMode: { type: String, computed: "_layoutMode(objectMode)" },
    itemClass: { type: String, computed: "_itemClass(layoutMode, objectMode)" },
    wrapperClass: { type: String, computed: "_wrapperClass(layoutMode, objectMode)" },
    minColWidth: { type: Number, computed: "_minColWidth(objectMode)" },
    maxColCount: { type: Number, computed: "_maxColCount(minColWidth)" },
    colClassList: { type: Number, computed: "_colClassList(maxColCount)" },
    hasNextPage: { 
      type: Boolean, 
      value: false,
      computed: "_hasNextPage(nextPage, items, itemsLoaded)" 
    },
    showPlaceholder: {
      type: Boolean,
      false: false,
      computed: "_showPlaceholder(items, itemsLoaded)"
    },
    isColumnMode: { type: Boolean, computed: "_isColumnMode(layoutMode)" },

    // Internal properties
    colCount: {
      type: Number,
      observer: "_colCountChanged"
    }
  },

  observers: [
    "_itemsChanged(items.*)"
  ],

  // Methods
  queryNextPage: function () {
    // Queries for the next page and APPENDS the results to the display, then increments nextPage.
    var self = this; // Hold onto the context variable
    self.setLoadingStatus(true);
    
    self.getResults(function(result) {
      if (result) {
        // Add all of the new results to the array (this will auto update the dom-repeat)
        for (var i = 0; i < result[self.objectMode].length; i++) {
          result[self.objectMode][i].selected = false; // add a selection property
          self.push('items', result[self.objectMode][i]);
        }
        
        // Store the new value of nextPage and exit loading status
        self.nextPage = result.next_page;
        self.setLoadingStatus(false);
      }
    }, function() {
      self.showError('An error occurred while trying to retrieve the next page of results.');
    });
  },
  refreshQuery: function () {
    // Resets nextPage to 1, then queries for the next page and REPLACES the existing results.
    var self = this; // Hold onto the context variable
    
    self.setLoadingStatus(true);
    self.nextPage = 1;
    while(self.items.length > 0) { self.pop('items'); } // clear out the existing items

    self.getResults(function(result) {
      if (result) {
        // Add all of the new results to the array (this will auto update the dom-repeat)
        for (var i = 0; i < result[self.objectMode].length; i++) {
          result[self.objectMode][i].selected = false; // add a selection property
          self.push('items', result[self.objectMode][i]);
        }
        
        // Store the new value of nextPage and exit loading status
        self.nextPage = result.next_page;
        self.setLoadingStatus(false);
      }
    }, function() {
      self.showError('An error occurred while trying to retrieve results.');
    });
  },
  selectAll: function() {
    for (var i = 0; i < this.items.length; i++)
      this.set("items.#" + i + ".selected", true);
  },
  deselectAll: function() {
    for (var i = 0; i < this.items.length; i++)
      this.set("items.#" + i + ".selected", false);
  },

  // Events
  ready: function() {
    // Set the loaded variable then initialize the items array
    if ((this.items == undefined) || (this.items == null))
      this.items = [];
    else
      this.itemsLoaded = true; // this is used by _showPlaceholder and _hasNextPage
  },
  attached: function() {
    // Register the column resize events if needed
    var self = this;
    if (this.isColumnMode) {
      $(window).on('resize', function() { self.updateColCount(); });
      self.updateColCount(); // update it on page load as well
    }

    // Refresh query if needed
    if (this.refreshQueryOnDisplay)
      this.refreshQuery();
  },
  _colCountChanged(newValue, oldValue) {
    if (this.isColumnMode && (newValue != oldValue)) {
      var classMap = { 1: "one-column", 2: "two-columns", 3: "three-columns", 4: "four-columns",
        5: "five-columns", 6: "six-columns" };
      var oldClass = classMap[oldValue];
      var newClass = classMap[newValue];

      $(this).find('.column-list').removeClass(oldClass).addClass(newClass);
    }
  },
  _itemsChanged(details) {
    if (details.path && details.path.endsWith(".selected")) {
      this.updateSelectedItems();
    }
  },

  // Property Computers
  _layoutMode: function(objectMode) {
    switch (objectMode) {
      case "badges": return "grid"; break;
      case "full_logs": return "column"; break;
      case "groups": return "grid"; break;
    }
  },
  _itemClass: function(layoutMode, objectMode) { return layoutMode + "-item " + objectMode; },
  _wrapperClass: function(layoutMode, objectMode) { return layoutMode + "-list " + objectMode; },
  _minColWidth: function(objectMode) {
    if (objectMode == "full_logs") return 600;
    else return null;
  },
  _maxColCount: function(minColWidth) { return Math.floor(2000/minColWidth); },
  _colClassList: function(maxColCount) {
    var returnValue = [];
    for (var i = 1; i <= maxColCount; i++)
      returnValue.push("column column-" + i);
    return returnValue;
  },
  _showPlaceholder: function(items, itemsLoaded) { 
    return itemsLoaded && items && (items.length == 0); 
  },
  _hasNextPage: function(nextPage, items, itemsLoaded) { 
    return itemsLoaded && items && (nextPage > 0); 
  },
  _isColumnMode: function(layoutMode) { return layoutMode == "column"; },
  _selectedItemCount: function(selectedItems) { return selectedItems ? selectedItems.length : 0; },
  _selectedItemCountChanged: function(newValue, oldValue) {
    // Update the selection bar if needed
    if (this.selectionBar)
      this.selectionBar.count = newValue;
  },

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
    }).error(function() { errorFunction(); });
  },
  setLoadingStatus: function(isLoading) {
    var nextPageButton = this.$$("#next-page-button");
    var spinner = this.$$("#spinner");
    var errorPanel = this.$$("#error-panel");

    if (isLoading) {
      nextPageButton.disabled = true;
      spinner.hidden = false; spinner.active = true;
      errorPanel.hidden = true;
    } else {
      nextPageButton.disabled = false;
      spinner.active = false; spinner.hidden = true;
    }
  },
  showError: function(errorMessage) {
    console.log(errorMessage);
    this.setLoadingStatus(false); // exit loading status if needed
    this.$$("#error-panel").hidden = false;
  },
  updateColCount: function() {
    // This gets run when the window is resized and will update the column count if needed
    // If will automatically make sure column count never goes below 1 or above maxColCount.
    if (this.isColumnMode) {
      var newColCount = Math.floor($(this).find('.column-list').width() / this.minColWidth);
      newColCount = Math.max(1, Math.min(this.maxColCount, newColCount));
      if (newColCount != this.colCount) this.colCount = newColCount;
    }
  },
  updateSelectedItems: function() {
    this.selectedItems = $.map(this.items, function(item, index) {
      if (item && item.selected) return item; 
    });
  }
});