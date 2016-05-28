Polymer({
  is: "bl-list-item",

  properties: {
    // Required
    objectMode: String, // = ['badges', 'full_logs', 'groups']
    item: { type: Object, notify: true, observer: 'itemChanged' },
    
    // Optional
    options: Object,

    // Computed properties
    isBadgeMode: { type: Boolean, computed: "_isBadgeMode(objectMode)" },
    isFullLogMode: { type: Boolean, computed: "_isFullLogMode(objectMode)" },
    isGroupMode: { type: Boolean, computed: "_isGroupMode(objectMode)" }
  },

  ready: function() {
    // The array template helper sometimes creates a blank element, so we need to filter it out.
    this.itemChanged(this.item, null);
  },

  // Computed properties
  _isBadgeMode: function(objectMode) { return objectMode == "badges"; },
  _isFullLogMode: function(objectMode) { return objectMode == "full_logs"; },
  _isGroupMode: function(objectMode) { return objectMode == "groups"; },

  // Events
  itemChanged: function(newValue, oldValue) {
    if (newValue) this.hidden = false;
    else this.hidden = true;
  }
});
