Polymer({
  is: "bl-entry-content",

  properties: {
    entry: Object,

    // Computed
    wrapperClass: { type: String, computed: "_wrapperClass(entry)" },
    isText: { type: Boolean, computed: "_isText(entry)" },
    isLink: { type: Boolean, computed: "_isLink(entry)" },
    isImage: { type: Boolean, computed: "_isImage(entry)" },
    isTweet: { type: Boolean, computed: "_isTweet(entry)" },
    isCode: { type: Boolean, computed: "_isCode(entry)" },
    linkTitle: { type: String, computed: "_linkTitle(entry)" },
    linkHasEmbed: { type: String, computed: "_linkHasEmbed(entry)" }
  },

  // Events
  attached: function() {
    // Load google pretty print if this is a code element
    if (this.entry && (this.entry.format == "code")) {
      addEventListener('load', function (event) { PR.prettyPrint() }, false);
    }
  },

  // Helpers
  blank: function(element) {
    return ((element == null) && (element == undefined)) ? true : false;
  },

  // Property computers
  _wrapperClass: function(entry) { 
    if (entry && entry.format) return entry.format & "-body"; 
  },
  _isText: function(entry) { return entry && (entry.format == "text"); },
  _isLink: function(entry) { return entry && (entry.format == "link"); },
  _isImage: function(entry) { return entry && (entry.format == "image"); },
  _isTweet: function(entry) { return entry && (entry.format == "tweet"); },
  _isCode: function(entry) { return entry && (entry.format == "code"); },
  _linkTitle: function(entry) {
    if (entry.link_metadata.title && entry.link_metadata.title.length)
      return entry.link_metadata.title;
    else
      return entry.link_url;
  },
  _linkHasEmbed: function(entry) {
    return entry && entry.link_metadata && entry.link_metadata.html 
      && (entry.link_metadata.html.trim().length > 0)
      && ((entry.link_metadata.type == 'rich') || (entry.link_metadata.type == 'video'));
  }

});

