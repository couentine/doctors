Polymer({
  is: "bl-grid-item",

  properties: {
    class: String,
    group: {
      type: Object,
      observer: 'groupChanged'
    }
  },

  ready: function() {
    this.groupChanged(this.group);
  },
  groupChanged: function(newValue) {
    if (newValue) this.hidden = false;
    else this.hidden = true;
  },

  has: function(objectVariable) {
    return (objectVariable != null) && (objectVariable != undefined);
  },
  goHover: function() {
    this.$$("paper-material").elevation = 5;
  },
  stopHover: function() {
    this.$$("paper-material").elevation = 0;
  },
  translateImageUrl: function(imageUrl) {
    // Needs translation to clear up the default state
    if (imageUrl == "default-group-avatar.png")
      return "/assets/default-group-avatar.png";
    else
      return imageUrl;
  }
});
