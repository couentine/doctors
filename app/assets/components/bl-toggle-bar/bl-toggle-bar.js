Polymer({
  is: "bl-toggle-bar",

  properties: {
    items: Array, // array of objects w/ keys: label, value
    selectedValue: { // you can set this to change the selected item
      type: String,
      notify: true,
      observer: '_selectedValueChanged'
    }, 
    selectedIndex: { type: Number, readOnly: true },
    selectedItem: { type: Object, readOnly: true },
    hasSelectedItem: { type: Boolean, readOnly: true, value: false, notify: true }
  },

  // Actions
  selectItem: function(e) { this.selectedValue = e.model.item.value },
  
  // Observers
  _selectedValueChanged: function(newValue, oldValue) {
    // First deselect the old item
    if (this.selectedIndex != null) {
      this.set('items.' + this.selectedIndex + '.selected', false);
      this.set('items.' + this.selectedIndex + '.class', 'unselected');
      this._setSelectedIndex(null);
      this._setSelectedItem(null);
      this._setHasSelectedItem(false);
    }
    
    // Then select the new item
    if (newValue && this.items)
      for (var i = 0; i < this.items.length; i++)
        if (this.items[i].value == newValue) {
          this._setHasSelectedItem(true);
          this.set('items.' + i + '.selected', true);
          this.set('items.' + i + '.class', 'selected');
          this._setSelectedIndex(i);
          this._setSelectedItem(this.items[i]);
        }
  }

});
