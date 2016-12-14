Polymer({
  is: "bl-full-log",

  properties: {
    fullLog: { type: Object },
    selectable: { type: Boolean, value: false }, // enables the select box
    hovered: { type: Boolean, notify: true },
    selected: { type: Boolean, notify: true },
    displayMode: { type: String, value: 'user' }, // = 'user', 'badge'
    
    // Managed automatically
    cardClass: { type: String },

    // Computed
    postsByTag: { type: Array, computed: "_postsByTag(fullLog)" },
    headerImageUrl: { type: String, computed: "_headerImageUrl(displayMode, fullLog)" },
    headerTitle: { type: String, computed: "_headerTitle(displayMode, fullLog)" },
    headerSubtitle: { type: String, computed: "_headerSubtitle(displayMode, fullLog)" },
    displayBadge: { type: String, computed: "_displayBadge(displayMode)" },
    requestDateString: { type: String, computed: "_requestDateString(fullLog)" }
  },

  observers: [
    "_fullLogSelectedChanged(fullLog.selected)"
  ],

  listeners: {
    // "checkbox.changed": "_selectedChanged"
    "card.mouseover": "_cardMouseOver",
    "card.mouseout": "_cardMouseOut",
    "header.tap": "_headerTap"
  },

  // Events
  _fullLogSelectedChanged: function(selected) { 
    this.set("selected", selected);
    this.set("cardClass", this.getCardClass(this.hovered, selected));
  },
  _headerTap: function(e) {
    if (e.target.id != "checkboxContainer")
      this.set("fullLog.selected", !this.selected);
  },

  // Helpers
  _cardMouseOver: function() {
    this.set("hovered", true);
    this.set("cardClass", this.getCardClass(this.hovered, this.selected));
  },
  _cardMouseOut: function() {
    this.set("hovered", false);
    this.set("cardClass", this.getCardClass(this.hovered, this.selected));
  },

  // Property Computers
  _postsByTag: function(fullLog) {
    // This function returns an array of objects, each with a 'parent_tag' key and a 'posts' key.

    var returnList = []; 
    var postMap = {}; // parent_tag => Array(posts)
    var post;

    if (this.fullLog && this.fullLog.posts && this.fullLog.posts.length ) {
      // First, loop through and organize the posts by map
      for (var i = 0; i < this.fullLog.posts.length; i++) {
        post = this.fullLog.posts[i];
        if (postMap[post.parent_tag]) postMap[post.parent_tag].push(post);
        else postMap[post.parent_tag] = [post];
      }

      // Now build the return value
      returnList = $.map(postMap, function(posts, parent_tag) {
        return { 'parent_tag': "#" + parent_tag, 'posts': posts };
      });
    }

    return returnList;
  },
  _headerImageUrl: function(displayMode, fullLog) {
    if ((displayMode == 'badge') && fullLog.badge && fullLog.badge.image_medium_url) {
      return fullLog.badge.image_medium_url;
    } else if (fullLog && fullLog.user_avatar_image_medium_url) 
      return fullLog.user_avatar_image_medium_url;
    else 
      return "https://secure.gravatar.com/avatar/0?s=200&d=mm";
  },
  _headerTitle: function(displayMode, fullLog) {
    if ((displayMode == 'badge') && fullLog.badge && fullLog.badge.name) 
      return fullLog.badge.name;
    else
      return fullLog.user_name;
  },
  _headerSubtitle: function(displayMode, fullLog) {
    if ((displayMode == 'badge') && fullLog.badge && fullLog.badge.url_with_caps) 
      return fullLog.badge.url_with_caps;
    else
      return fullLog.user_username_with_caps;
  },
  _displayBadge: function(displayMode) { return (displayMode == 'badge'); },
  _requestDateString: function(fullLog) {
    if (fullLog && fullLog.date_requested) {
      var d = new Date(fullLog.date_requested*1000);
      return "Requested " + d.toLocaleString();
    } else return "";
  },

  // Helpers
  getCardClass: function(hovered, selected) { 
    return this.displayMode + (selected ? " selected " : " ") + (hovered ? "hovered" : ""); 
  }
});