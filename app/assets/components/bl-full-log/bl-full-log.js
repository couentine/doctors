Polymer({
  is: "bl-full-log",

  properties: {
    fullLog: Object,
    selectable: { type: Boolean, value: false }, // enables the select box
    selected: { type: Boolean, value: false },

    // Computed
    avatarUrl: { type: String, computed: "_avatarUrl(fullLog)" },
    requestDateString: { type: String, computed: "_requestDateString(fullLog)" }
  },

  // listeners: {
  //   'paper.mouseover': 'paperMouseOver',
  //   'paper.mouseout': 'paperMouseOut'
  // },

  // Events
  toggleSelected: function() { this.select = !this.select; },

  // Helpers
  paperMouseOver: function() {
    this.$.paper.elevation = 3;
  },
  paperMouseOut: function() {
    this.$.paper.elevation = 0;
  },

  // Property Computers
  _avatarUrl: function(fullLog) {
    if (fullLog && fullLog.user_avatar_image_medium_url) 
      return fullLog.user_avatar_image_medium_url;
    else 
      return "https://secure.gravatar.com/avatar/0?s=200&d=mm";
  },
  _requestDateString: function(fullLog) {
    if (fullLog && fullLog.date_requested) {
      var d = new Date(fullLog.date_requested*1000);
      return "Requested " + d.toLocaleString();
    } else return "";
  }
});