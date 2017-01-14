Polymer({
  is: "bl-toast",

  properties: {
    class: String,
    text: String,
    autoCloseAfter: { type: Number, value: 3000 } // in milliseconds, set to 0 to disable autoclose
  },

  // Events
  attached: function() {
    // Queue autoclose
    var self = this;
    if (this.autoCloseAfter > 0)
      setTimeout(function() { self.closeToast(); }, this.autoCloseAfter);
  },

  // Actions
  closeToast: function() {
    $(this).fadeOut();
  }
});
