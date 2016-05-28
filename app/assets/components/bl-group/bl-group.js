Polymer({
  is: "bl-group",

  properties: {
    group: Object,
    link: { type: Boolean, value: false }
  },

  listeners: {
    'paper.mouseover': 'paperMouseOver',
    'paper.mouseout': 'paperMouseOut'
  },

  // Helpers
  paperMouseOver: function() {
    this.$.paper.elevation = 3;
  },
  paperMouseOut: function() {
    this.$.paper.elevation = 0;
  },
  translateImageUrl: function(imageUrl) {
    // Needs translation to clear up the default state
    if (imageUrl == "default-group-avatar.png")
      return "/assets/default-group-avatar.png";
    else
      return imageUrl;
  }
});