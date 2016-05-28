/* ================================================== */
/* =========>> BL QUERY OPTIONS COMPONENT <<========= */
/* ================================================== */

/*
  This component is meant to update the queryOptions property of a bl-list.

  This component should have as its content a single paper-dropdown-menu with paper-items that 
  represent user-facing descriptions of the various query key value combinations. Each paper-item 
  should have a data-options property that is set to a json object with keys and values which
  will be overriden on the bl-list when the item is selected in the dropdown. After the options
  change the refreshQuery() method will be called on the bl-list.

  The selectedOptions property should have keys and values matching one of the paper-items 
  (or should be blank).
*/

Polymer({
  is: "bl-query-options",

  properties: {
    for: String, // the id of the bl-list, used to set this.targetList
    selectedOptions: Object, // used to set the initial state of the drowdown on load

    // Automatically set
    targetList: Object,
    listbox: Object,
    initialized: { type: Boolean, value: false }
  },

  // Events
  attached: function() {
    // First link the targetList
    if (this.for && document.querySelector("#" + this.for))
      this.targetList = document.querySelector("#" + this.for);
    
    // Then handle the listbox
    if (Polymer.dom(this).querySelector('paper-listbox')) {
      this.listbox = Polymer.dom(this).querySelector('paper-listbox');

      // Now set the selected item if possible
      if (this.selectedOptions && (Object.keys(this.selectedOptions).length > 0)) {
        var items = this.listbox.querySelectorAll('paper-item');
        var itemMatches; var itemOptions;
        
        for (var i = 0; i < items.length; i++) {
          itemOptions = $(items[i]).data("options");
          itemMatches = true;

          for (var key in this.selectedOptions)
            if (this.selectedOptions.hasOwnProperty(key))
              itemMatches = itemMatches && (this.selectedOptions[key] == itemOptions[key]);
          
          // If ALL of the selectedOptions match, then select this one and end the loop
          if (itemMatches) {
            this.listbox.selected = i;
            break;
          }
        }
      }

      // Now register the event listener that will listen for changes to the selection
      this.listen(this.listbox, "iron-select", "_selectedItemChanged");
    }

    // Now mark initialization complete (delayed a bit so it doesn't fire on first load)
    var self = this;
    setTimeout(function() { self.initialized = true; }, 200);
  },
  _selectedItemChanged: function(e) {
    // When the list box selection changes we extract the item from the passed event and then
    // pass the options to the targetList. (But first we make sure that we're initialized.)
    if (this.initialized && this.targetList) {
      this.targetList.updateQueryOptions($(e.detail.item).data("options"));
    }
  }

});
