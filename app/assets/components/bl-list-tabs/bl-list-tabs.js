/* ================================================== */
/* =============>> BL LIST TABS <<============== */
/* ================================================== */

/*
  TODO: Fill this out.
*/

Polymer({
  is: "bl-list-tabs",
  properties: {
    tabs: Array, //Array of onjects with two keys: label and value
    wrapperClass: String,
    selectedListId: { type: String, notify: true, observer: '_selectedListIdChanged' },
    childMap: Object
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
