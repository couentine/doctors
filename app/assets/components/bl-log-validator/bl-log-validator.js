Polymer({
  is: "bl-log-validator",

  properties: {
    for: String, // set this to the id of the source bl-list
    
    // Internally managed
    sourceList: Object, // set automatically based on this.for
    summary: String,
    body: String,
    selectedLogs: Array,

    // Computed
    logCount: { type: Number, value: 0, computed: "_logCount(selectedLogs)" }
  },

  // Methods
  open: function() { 
    // First update the logs
    this.selectedLogs = this.sourceList.selectedItems;

    // Then show the dialog
    this.$.dialog.open(); 
  },

  // Events
  attached: function() {
    if (this.for && document.querySelector("#" + this.for)) 
      this.sourceList = document.querySelector("#" + this.for);
  },

  // Property Computers
  _logCount: function(selectedLogs) { 
    return (selectedLogs && selectedLogs.length) ? selectedLogs.length : 0; 
  }

});
