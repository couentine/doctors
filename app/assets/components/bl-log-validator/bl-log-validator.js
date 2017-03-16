Polymer({
  is: "bl-log-validator",

  properties: {
    for: String, // set this to the id of the source bl-list
    groupValidationsPath: String, // group_validations_path(@group) rails helper
    
    // Internally managed
    sourceList: Object, // set automatically based on this.for
    summary: String,
    body: String,
    selectedLogs: Array,

    // Computed
    logCount: { type: Number, value: 0, computed: "_logCount(selectedLogs)" },
    logIds: { type: Number, value: 0, computed: "_logIds(selectedLogs)" }
  },

  listeners: {
    "feedback.tap": "submitWithoutEndorsement",
    "endorse.tap": "submitWithEndorsement"
  },

  // Methods
  open: function() { 
    // First update the logs
    this.selectedLogs = this.sourceList.selectedItems;

    // Then show the dialog
    this.$['input-dialog'].open(); 
  },
  submitWithEndorsement: function() { this.submit(true); }, 
  submitWithoutEndorsement: function() { this.submit(false); }, 
  submit: function(withEndorsement) {
    withEndorsement = (withEndorsement == true) ? true : false; // explicitly define if undefined

    if (!this.$.summary.validate()) {
      alert("The summary field is required.");
      this.$.summary.focus();
    } else {
      var queryUrl; var queryParams;
      var self = this;
      var bodyText;

      // First build the query url
      bodyText = this.body ? this.body.replace(/(?:\r\n|\r|\n)/g, "<br>") : "";
      queryParams = { 
        "summary": this.summary,
        "body": bodyText,
        "logs_validated": withEndorsement,
        "log_ids": self.logIds
      }
      queryUrl = self.groupValidationsPath + "?" + $.param(queryParams);

      // Then do the post
      $.post(queryUrl, function(result) {
        if (result == null) 
          alert("There was a problem posting your feedback, the server returned a blank result. "
            + "Please try again later.");
        else if (result.error_message && result.error_message.trim().length)
          alert("There was a problem posting your feedback, the server returned an error. "
            + "(Error Message: " + result.error_message + ")");
        else if (result.poller_id && result.poller_id.trim().length) {
          // Everything looks good, clear the selected items and then switch to the progress modal
          self.sourceList.removeSelectedItems();
          self.$['input-dialog'].close();
          self.$['progress-dialog'].open();
          self.$.poller.pollerId = result.poller_id; // this will start the polling process
        } else // This *should* be impossible.
          alert("Your feedback may not have been posted, please check and try again.");
      }).error(function(e) { 
        alert("An error occured, please try again later. (Details: " + e + ")");
      });
    }
  },

  // Events
  attached: function() {
    if (this.for && document.querySelector("#" + this.for)) 
      this.sourceList = document.querySelector("#" + this.for);

    this.listen(this.$['input-dialog'], "iron-overlay-opened", "_dialogOpened");
  },
  _dialogOpened: function(e) { this.$.summary.focus(); },

  // Property Computers
  _logCount: function(selectedLogs) { 
    return (selectedLogs && selectedLogs.length) ? selectedLogs.length : 0; 
  },
  _logIds: function(selectedLogs) { 
    if (selectedLogs)
      return $.map(selectedLogs, function(item, index) { return item.id }); 
    else
      return [];
  }

});
