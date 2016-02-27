Polymer({
  is: "bl-grid-item",

  properties: {
    // Required
    mode: String, // = ['badge', 'group']
    
    // Optional
    options: Object,

    // Mode-specifid
    badge: {
      type: Object,
      observer: 'itemChanged'
    },
    group: {
      type: Object,
      observer: 'itemChanged'
    },

    // Computed properties
    isBadgeMode: {
      type: Boolean,
      computed: "_isBadgeMode(mode)"
    },
    isGroupMode: {
      type: Boolean,
      computed: "_isGroupMode(mode)"
    }
  },

  // Computed properties
  _isBadgeMode: function(mode) { return mode == "badge"; },
  _isGroupMode: function(mode) { return mode == "group"; },

  // Events
  ready: function() {
    if (this.mode == "group") this.itemChanged(this.group);
    else if (this.mode == "badge") this.itemChanged(this.badge);
  },
  itemChanged: function(newValue) {
    if (newValue) this.hidden = false;
    else this.hidden = true;
  },
  goHover: function() {
    this.$$("paper-material").elevation = 3;
  },
  stopHover: function() {
    this.$$("paper-material").elevation = 0;
  },
  
  // Helpers
  translateImageUrl: function(imageUrl) {
    // Needs translation to clear up the default state
    if (imageUrl == "default-group-avatar.png")
      return "/assets/default-group-avatar.png";
    else
      return imageUrl;
  }
});
