Polymer({
  is: "bl-toast",

  properties: {
    class: String,
    text: String
  },

  closeToast: function() {
    $(this).fadeOut();
  }
});
