blToast = Polymer({
  is: "bl-toast",

  properties: {
    text: String,
    type: String, // OPTIONAL = ['notice', error', 'warning', 'success']
    autoCloseAfter: { type: Number, value: 3000 } // in milliseconds, set to 0 to disable autoclose
  },

  // Custom Constructor
  factoryImpl: function(text, type, autoCloseAfter) {
    // Leave type or autoCloseAfter blank to use the default
    this.text = text;
    this.type = type;
    if ((autoCloseAfter != undefined) && (autoCloseAfter != null))
      this.autoCloseAfter = autoCloseAfter;
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
