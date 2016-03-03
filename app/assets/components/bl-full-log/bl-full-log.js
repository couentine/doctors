Polymer({
  is: "bl-full-log",

  properties: {
    fullLog: Object,
    link: { type: Boolean, value: false }
  },

  // listeners: {
  //   'paper.mouseover': 'paperMouseOver',
  //   'paper.mouseout': 'paperMouseOut'
  // },

  // Helpers
  paperMouseOver: function() {
    this.$.paper.elevation = 3;
  },
  paperMouseOut: function() {
    this.$.paper.elevation = 0;
  }
});