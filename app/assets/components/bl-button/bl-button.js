Polymer({
  is: "bl-button",

  properties: {
    type: String,
    link: String,
    target: String,
    raised: {
      type: String,
      computed: "isRaised(type)"
    }
  },

  isRaised: function(type) {
    return type == "raised";
  }
});
