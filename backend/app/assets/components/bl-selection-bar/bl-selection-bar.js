Polymer({
  is: "bl-selection-bar",

  // @event deselect-all: Fired when the desect all button is clicked.

  properties: {
    for: String, // set this to the id of the bl-list
    count: { type: Number, value: 0 },
    nounSingular: { type: String, value: "item" },
    nounPlural: { type: String, value: "items" },

    // Computed
    barClass: { type: String, computed: "_barClass(count)" },
    labelText: { type: String, computed: "_labelText(count, nounSingular, nounPlural)" }
  },

  listeners: {
    "deselect.tap": "deselectAll"
  },

  // Methods
  deselectAll: function() { 
    // Fire the event and then call out to the bl-list directly if possible
    this.fire('deselect-all', { target: this }); 
    if (this.for && document.querySelector("#" + this.for))
      document.querySelector("#" + this.for).deselectAll();
  },

  // Events
  attached: function() {
    if (this.for && document.querySelector("#" + this.for))
      document.querySelector("#" + this.for).selectionBar = this;
  },

  // Property Computers
  _barClass: function(count) { return "bar " + ((count > 0) ? "expanded" : "collapsed"); },
  _labelText: function(count, nounSingular, nounPlural) { 
    if (count == 1) return "1 " + nounSingular + " selected";
    else return count + " " + nounPlural + " selected";
  }
});
