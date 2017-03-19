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

  How to use injectItems:
    This object can be used to have the list "inject" json into the item values which are returned 
    from the server. To do this, add a key to injectItems equal to object name (ex: 'badge').
    In that example, the 'badge' key should have an object value with keys equal to badge ids.
    Each badge id key would then have a value equal to the badge json. In this example, bl-list
    will look for a 'badge_id' key in the item json and, if a match is found with injectItems, 
    the matched item is injected into a new 'badge' key (any existing value will be overwritten).

  How to use simpleMode:
    Normally bl-list works by generating bl-list-item children for each item. Then the format
    is set to grid or column based on what looks best for that object type. But simple mode is 
    simpler, generating a collection of paper icon list items mashed together. To use
    simple mode: set simpleMode=true, set rowTitleKey=field on each item that holds the title,
                 and set either rowImageKey=field, rowIconKey=field OR rowIcon=one icon for all.
    If you add the 'selectable' property then item selection is built in.
    If you leave out the 'selectable' property then you can optionally set the 'rowLinkKey' 
    property to an item field with returns a url or path to follow when the item is clicked.

  How to use ajax targetting:
    When bl-list is used as a multi-select tool, it is typically for the purposes of generating 
    a list of unique identifiers to pass to an ajax call. So bl-list includes the ability to target
    an iron-ajax element and build a list of unique identifiers for all of the currently selected
    items. To do this, set forAjax to the iron-ajax's id. Then set ajaxItemKey to the key on 
    the bl-list items which represents the unique identifiers (ex: 'id' or 'username').
    Then set the ajaxBodyKey to the name of the array parameter expected by the rails controller
    (ex: 'user_ids' or 'users').

*/

Polymer({
  is: "bl-list",

  properties: {
    // Required
    objectMode: String, // = ['badges', 'full_logs', 'groups', 'group_tags', 'users']
    nextPageUrl: String, // and ampersand + next page and query options are appended to this
    nextPage: { type: Number, value: 1 },
    nextPageParam: { type: String, value: 'page' },
    
    // Options
    queryOptions: Object, // Added to next page query: "&key1=value1&key2=value2" ...
    options: Object,
    refreshQueryOnLoad: { type: Boolean, value: false }, // refreshes when component is attached
    selectionBar: Object, // this gets set by the bl-selection-bar when the "for" property is set
    itemDisplayMode: String, // OPTIONAL: Passed all the way to the individual items (if supported)
    itemParentPath: String, // REQUIRED for items that don't know parent path, ex val: '/Group-Name'
    
    // Simple Mode Options
    simpleMode: { type: Boolean, value: false }, // explained in comments at top of file
    selectable: { type: Boolean, value: false }, // enables selection of items
    rowTitleKey: String, // field name of title in items (required)
    rowLinkKey: { type: String, value: null }, // field name of url or path in items (optional)
    rowImageKey: { type: String, value: null }, // field name of image in items (1 of these req'd)
    rowIconKey: { type: String, value: null }, // field name of icon in items (1 of these req'd)
    rowIcon: { type: String, value: null }, // icon to use for ALL items (1 of these req'd)
    roundRowImage: Boolean, // set this to round the row image

    // Ajax Targetting Options (Explained in top comments)
    forAjax: String, // Set this to the id of an iron-ajax
    ajaxItemKey: String, // The source item key to copy to array in iron-ajax body
    ajaxBodyKey: String, // The destination key in iron-ajax body used to store the array
    
    // The object items
    items: { type: Array, notify: true },
    itemsLoaded: { type: Boolean, value: false }, // set automatically
    selectedItems: { type: Array, value: function() { return []; } },
    selectedItemCount: { type: Number, value: 0, computed: '_selectedItemCount(selectedItems)',
      observer: '_selectedItemCountChanged' },
    hasItems: { type: Boolean, computed: '_hasItems(items.length)', observer: '_hasItemsChanged' },
    hasUnselectedItems: { type: Boolean, 
      computed: '_hasUnselectedItems(items.length, selectedItemCount)',
      observer: '_hasUnselectedItemsChanged' },
    injectItems: { type: Object }, // refer to header comments for specifics

    // Computed
    layoutMode: { type: String, computed: '_layoutMode(objectMode, simpleMode)' },
    itemClass: { type: String, computed: '_itemClass(layoutMode, objectMode)' },
    wrapperClass: { type: String, computed: '_wrapperClass(layoutMode, objectMode)' },
    minColWidth: { type: Number, computed: '_minColWidth(objectMode)' },
    maxColCount: { type: Number, computed: '_maxColCount(minColWidth)' },
    colClassList: { type: Number, computed: '_colClassList(maxColCount)' },
    isColumnMode: { type: Boolean, computed: '_isColumnMode(layoutMode)' },
    isColumnMode: { type: Boolean, computed: '_isColumnMode(layoutMode)' },
    isGridMode: { type: Boolean, computed: '_isGridMode(layoutMode)' },
    hasNextPage: { type: Boolean, value: false, 
      computed: '_hasNextPage(nextPage, items, itemsLoaded, loading)' },
    showPlaceholder: { type: Boolean, false: false, 
      computed: '_showPlaceholder(items.length, itemsLoaded, loading)' },

    showImageKey: { type: Boolean, computed: '_showImageKey(rowImageKey)' },
    showIconKey: { type: Boolean, computed: '_showIconKey(rowImageKey, rowIconKey)' },
    showIcon: { type: Boolean, computed: '_showIcon(rowImageKey, rowIconKey)' },

    // Internal properties
    colCount: { type: Number, observer: '_colCountChanged' },
    loading: { type: Boolean, value: false },
    indexLastSelected: Number
  },

  observers: [
    '_itemsChanged(items.*)'
  ],

  // Actions
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
  // This method will overwrite all of the query options parameters contained in the passed object
  // (leaving other options the same) and will then refresh the query.
  updateQueryOptions: function(newQueryOptions) {
    for (var key in newQueryOptions)
      if (newQueryOptions.hasOwnProperty(key))
        this.queryOptions[key] = newQueryOptions[key];

    this.refreshQuery();
  },
  simpleItemTap: function(e) {
    // Fires when a simple item is tapped

    if (this.selectable) this.toggleItem(e);
    else this.followItemLink(e);
  },
  followItemLink: function(e) {
    // Called from non-selectable simple item row to follow the item link if present
    // If there's no link then nothing happens when the user clicks
    var index = e.model.index;
    if (this.items[index].row.link) 
      document.location.href = this.items[index].row.link;
  },
  toggleItem: function(e) {
    // Called from selectable simple item row to toggle that item's selection
    var index = e.model.index;

    // First we toggle the selection
    this.set('items.' + index + '.selected', !this.items[index].selected);

    // Then we handle shift click events. This occurs when two selection events occur in a row
    // and the shift key is held down during the second selection event.
    var isSelected = this.items[index].selected;
    if (isSelected && e.detail.sourceEvent.shiftKey && (this.indexLastSelected != null)) {
      // Then this is the second click in a shift-click, so we select all those in between
      var startIndex = Math.min(this.indexLastSelected, index);
      var stopIndex = Math.max(this.indexLastSelected, index);
      for (var i = startIndex; i < stopIndex; i++)
        this.set('items.' + i + '.selected', true);

      this.indexLastSelected = null;
    } else {
      this.indexLastSelected = (isSelected) ? index : null;
    }

    // Finally, if the shift key is held down we might need to clear the selected text
    if (e.detail.sourceEvent.shiftKey) {
      if (window.getSelection) {
        if (window.getSelection().empty) {  // Chrome
          window.getSelection().empty();
        } else if (window.getSelection().removeAllRanges) {  // Firefox
          window.getSelection().removeAllRanges();
        }
      } else if (document.selection) {  // IE?
        document.selection.empty();
      }
    }
  },
  selectAll: function() {
    var childrenToNotify = this.querySelectorAll('bl-list-item');

    for (var i = 0; i < this.items.length; i++) {
      this.items[i].selected = true;
      this.notifyPath("items.#" + i + ".selected", true)
    }
    
    // Manually run this since it doesn't get run sometimes when we use the notification method
    this.updateSelectedItems();

    // Now update child elements as needed
    for (var i=0; i < childrenToNotify.length; i++)
      childrenToNotify[i].notifySelectionChanged();
  },
  deselectAll: function() {
    var childrenToNotify = this.querySelectorAll('bl-list-item');

    for (var i = 0; i < this.items.length; i++) {
      this.items[i].selected = false;
      this.notifyPath("items.#" + i + ".selected", false)
    }

    // Manually run this since it doesn't get run sometimes when we use the notification method
    this.updateSelectedItems();

    // Now update child elements as needed
    for (var i=0; i < childrenToNotify.length; i++)
      childrenToNotify[i].notifySelectionChanged();
  },
  removeSelectedItems: function() {
    // This method will remove all of the selected items from the items array.
    // If that leaves the items array empty, then this method will call refreshQuery().

    if (this.items && this.items.length) {
      for (var i = this.items.length - 1; i >= 0; i--) // loop backwards so indexes won't change
        if (this.items[i].selected)
          this.splice('items', i, 1);
    
      if (this.items.length == 0) this.refreshQuery();
    }
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
    if (this.refreshQueryOnLoad)
      this.refreshQuery();
    else if (this.simpleMode)
      for (var i = 0; i < this.items.length; i++)
        this.injectRowProperties(this.items[i]);
  },
  _colCountChanged: function(newValue, oldValue) {
    if (this.isColumnMode && (newValue != oldValue)) {
      var classMap = { 1: "one-column", 2: "two-columns", 3: "three-columns", 4: "four-columns",
        5: "five-columns", 6: "six-columns" };
      var oldClass = classMap[oldValue];
      var newClass = classMap[newValue];

      $(this).find('.column-list').removeClass(oldClass).addClass(newClass);
    }
  },
  _itemsChanged: function(details) {
    if (details.path) {
      if (details.path.endsWith(".selected") || details.path.endsWith(".length"))
        this.updateSelectedItems();
    }
  },
  _hasItemsChanged: function(newValue, oldValue) {
    // Hide query options
    // NOTE: We'll hide it by setting the scale to 0, so it can be animated if desired.
    if (newValue) {
      $(Polymer.dom(this).querySelectorAll('.query-filter-option')).css('transform', 'scale(1)');
    } else {
      $(Polymer.dom(this).querySelectorAll('.query-filter-option')).css('transform', 'scale(0)');
    }
  },
  _hasUnselectedItemsChanged: function(newValue, oldValue) {
    // Hide any buttons with class 'select-all-button' anywhere in the light DOM
    // NOTE: We'll hide it by setting the scale to 0, so it can be animated if desired.
    if (newValue)
      $(Polymer.dom(this).querySelectorAll('.select-all-button')).css('transform', 'scale(1)');
    else
      $(Polymer.dom(this).querySelectorAll('.select-all-button')).css('transform', 'scale(0)');
  },

  // Property Computers
  _layoutMode: function(objectMode, simpleMode) {
    if (simpleMode) return 'simple';
    else if (objectMode == 'full_logs') return 'column';
    else return 'grid';
  },
  _itemClass: function(layoutMode, objectMode) { return layoutMode + "-item " + objectMode; },
  _wrapperClass: function(layoutMode, objectMode) { return layoutMode + "-list " + objectMode; },
  _minColWidth: function(objectMode) {
    if (objectMode == "full_logs") return 500;
    else return 2000;
  },
  _maxColCount: function(minColWidth) { return Math.floor(2000/minColWidth); },
  _colClassList: function(maxColCount) {
    var returnValue = [];
    for (var i = 1; i <= Math.min(10, maxColCount); i++)
      returnValue.push("column column-" + i);
    return returnValue;
  },
  _showPlaceholder: function(itemsLength, itemsLoaded, loading) { 
    return itemsLoaded && !loading && !itemsLength; 
  },
  _showImageKey: function(rowImageKey) {
    return (rowImageKey != null) && (rowImageKey != undefined);
  },
  _showIconKey: function(rowImageKey, rowIconKey) {
    return ((rowImageKey == null) || (rowImageKey == undefined))
      && (rowIconKey != null) && (rowIconKey != undefined);
  },
  _showIcon: function(rowImageKey, rowIconKey) {
    return ((rowImageKey == null) || (rowImageKey == undefined))
      && ((rowIconKey == null) || (rowIconKey == undefined));
  },
  _hasNextPage: function(nextPage, items, itemsLoaded, loading) { 
    return itemsLoaded && !loading && items && (nextPage > 0); 
  },
  _isColumnMode: function(layoutMode) { return layoutMode == "column"; },
  _isGridMode: function(layoutMode) { return layoutMode == "grid"; },
  _selectedItemCount: function(selectedItems) { return selectedItems ? selectedItems.length : 0; },
  _selectedItemCountChanged: function(newValue, oldValue) {
    // Update the selection bar if needed
    if (this.selectionBar)
      this.selectionBar.count = newValue;
  },
  _hasItems: function(itemsLength) { return itemsLength > 0; },
  _hasUnselectedItems: function(itemsLength, selectedItemCount) {
    if (itemsLength) 
      if (selectedItemCount) return itemsLength > selectedItemCount;
      else return true;
    else return false;
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
        if (queryOptions[key] != null)
          fullUrl += "&" + key + "=" + queryOptions[key];
      });

    return fullUrl;
  },
  // Queries next page & runs either completeFunction(results) or errorFunction()
  getResults: function(completeFunction, errorFunction) { 
    var self = this;

    $.getJSON(this.getFullUrl(), function(result) {
      if (result) {
        var sourceObjects; var objectIdField;
        var resultItems = result[self.objectMode]; // array of result items
        
        if (resultItems && resultItems.length) {
          // First we need to inject the extra items if specified
          if (self.injectItems)
            for (var objectName in self.injectItems)
              if (self.injectItems.hasOwnProperty(objectName) && self.injectItems[objectName]) {
                // Create shortcuts to make code more readable
                sourceObjects = self.injectItems[objectName]; // keys = object ids, values = objects
                objectIdField = objectName + '_id';

                // Now loop through resultItems. For each item with an 'object_id' field value 
                // that matches a key in sourceObjects we will inject the matching object
                // directly into a NEW result item key called 'object'.
                for (var i = 0; i < resultItems.length; i++)
                  if (resultItems[i][objectIdField] && sourceObjects[resultItems[i][objectIdField]])
                    resultItems[i][objectName] = sourceObjects[resultItems[i][objectIdField]];
              }
                
          // Next we inject the row properties if this is simple mode
          if (self.simpleMode)
            for (var i = 0; i < resultItems.length; i++)
              self.injectRowProperties(resultItems[i]);
        }

        // Then we can call the complete function
        self.itemsLoaded = true;
        completeFunction(result);
      } else errorFunction();
    }).error(function() { errorFunction(); });
  },
  injectRowProperties: function(item) {
    item.row = { title: item[this.rowTitleKey] };

    if (this.showImageKey)
      item.row.image = item[this.rowImageKey];
    else if (this.showIconKey)
      item.row.icon = item[this.rowIconKey];

    if (this.rowLinkKey)
      item.row.link = item[this.rowLinkKey];
  },
  setLoadingStatus: function(isLoading) {
    var nextPageButton = this.$$("#next-page-button");
    var spinner = this.$$("#spinner");
    var errorPanel = this.$$("#error-panel");

    if (isLoading) {
      nextPageButton.disabled = true;
      spinner.hidden = false; spinner.active = true;
      errorPanel.hidden = true;
      this.loading = true;
    } else {
      nextPageButton.disabled = false;
      spinner.active = false; spinner.hidden = true;
      this.loading = false;
    }
  },
  showError: function(errorMessage) {
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
    // Update the main selected items array
    this.selectedItems = $.map(this.items, function(item, index) {
      if (item && item.selected) return item; 
    });

    // Then potentially update the ajax
    if (this.forAjax) {
      var ajaxBody = {};
      ajaxBody[this.ajaxBodyKey] = [];
      
      // Extract ajaxItemKey from each item and store it in the ajaxBodyKey array on ajaxBody
      for (var i = 0; i < this.selectedItems.length; i++)
        ajaxBody[this.ajaxBodyKey].push(this.selectedItems[i][this.ajaxItemKey]);

      document.getElementById(this.forAjax).body = ajaxBody;
    }
  },
  rowClass: function(itemSelected) {
    // Called in simple mode to calculate the class of he paper items
    return this.layoutMode + '-item ' + this.objectMode + (itemSelected ? ' selected' : '');
  }
});