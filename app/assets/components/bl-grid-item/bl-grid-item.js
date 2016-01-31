Polymer({
  is: "bl-grid-item",

  properties: {
    class: String,
    group: Object
  },

  has: function(objectVariable) {
    return objectVariable != null;
  },
  goHover: function() {
    this.$$("paper-material").elevation = 5;
  },
  stopHover: function() {
    this.$$("paper-material").elevation = 0;
  }
});
