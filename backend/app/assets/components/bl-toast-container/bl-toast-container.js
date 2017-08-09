Polymer({
  is: "bl-toast-container",

  // Actions
  addToast: function(text, type, autoCloseAfter) {
    // Creates a new toast item, appends it to the list and displays it right away
    // Leave type or autoCloseAfter blank to use the default
    this.appendChild(new blToast(text, type, autoCloseAfter));
  }
});
