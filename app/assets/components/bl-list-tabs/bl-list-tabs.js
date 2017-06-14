/* ================================================== */
/* =============>> BL LIST TABS <<============== */
/* ================================================== */

/*
  This component creates a tabbed user interface for bl-lists passed in as content to the element.
  A passed in bl-list will automatically populate the number of tabs and their names when passed in.

  The coponent has an optional param, selectedListId, which determines which tab should be selected
  when the component is displayed.

  Styling: Set the class to one of ['orange', 'green', 'blue', 'grey']
*/

Polymer({
  is: "bl-list-tabs",
  properties: {
    //Optional
    selectedListId: { type: String, notify: true, observer: '_selectedListIdChanged' },
    //Computed
    childMap: Object, //Array of bl-lists passed in to the bl-list-tabs component
    tabs: Array //Array of objects with two keys: label and value, based on bl-list items
  },

  attached: function() {
    var lightDOMChildren = this.getContentChildren();
    this.tabs = [];
    this.childMap = {};
    var self = this;

    lightDOMChildren.forEach(function(childNode) {
      if (childNode.tagName.toLowerCase() === 'bl-list') {
        childNode.hidden = self.selectedListId != childNode.id;
        if (!childNode.hidden)
          childNode.refreshQuery();

        self.childMap[childNode.id] = childNode;
        self.push('tabs', {label: childNode.name, value: childNode.id});
        if (!self.wrapperClass)
          self.wrapperClass = childNode.wrapperClass;
      }
    });
  },
  
  _selectedListIdChanged: function(newVal, oldVal) {
    if (this.childMap) {
      if (oldVal) this.childMap[oldVal].hidden = true; 
      if (newVal) {
        this.childMap[newVal].hidden = false; 
        if (!this.childMap[newVal].itemsLoaded)
          this.childMap[newVal].refreshQuery();
      } 
    }
  }
});
