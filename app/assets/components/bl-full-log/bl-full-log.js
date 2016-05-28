Polymer({
  is: "bl-full-log",

  properties: {
    fullLog: { type: Object },
    selectable: { type: Boolean, value: false }, // enables the select box
    hovered: { type: Boolean, notify: true },
    selected: { type: Boolean, notify: true },
    
    // Managed automatically
    cardClass: { type: String },

    // Computed
    postsByTag: { type: Array, computed: "_postsByTag(fullLog)" },
    avatarUrl: { type: String, computed: "_avatarUrl(fullLog)" },
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
    this.set("cardClass", this._cardClass(this.hovered, selected));
  },
  _headerTap: function(e) {
    if (e.target.id != "checkboxContainer")
      this.set("fullLog.selected", !this.selected);
  },

  // Helpers
  _cardMouseOver: function() {
    this.set("hovered", true);
    this.set("cardClass", this._cardClass(this.hovered, this.selected));
  },
  _cardMouseOut: function() {
    this.set("hovered", false);
    this.set("cardClass", this._cardClass(this.hovered, this.selected));
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
  },
  _cardClass: function(hovered, selected) { 
    return (selected ? "selected " : " ") + (hovered ? "hovered" : ""); 
  }
});