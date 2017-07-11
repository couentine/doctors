Polymer({
  is: "bl-app-header-home",

  properties: {
    rootUrl: { type: String, value: 'https://www.badgelist.com' },
    condensedHeightEm: { type: Number, value: 6.1, readOnly: true } // used by bl-app-container
  },

  // Listeners
  _headerPanelTransform: function(e) {
    var detail = e.detail; // detail keys = [condensedHeight, height, y]
    var y = detail.y;

    // Move the top line down to accomodate the condensed space
    var newY = (y === null) ? null : Math.min(y, detail.height - detail.condensedHeight);
    this.transform((newY === null) ? '' : 'translate3d(0, ' + newY + 'px, 0)', this.$.topLine);
  },

  // Events
  attached: function() {
    // Listen for the transform event
    var self = this;
    document.addEventListener('paper-header-transform', function(e) {
      self._headerPanelTransform(e);
    });
  },
  ready: function() {
    // Notify bl-app-container of the condensedHeaderHeight
    this.fire('bl-app-header-content-ready', { condensedHeightEm: this.condensedHeightEm });
  },

  // Helpers
  getUrl: function(relativeURL) {
    return (this.rootUrl) ? (this.rootUrl + relativeURL) : relativeURL;
  }  
});
