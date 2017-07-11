Polymer({
  is: "bl-app-header-tag",

  properties: {
    name: String, // Required: The tag name
    backUrl: String, // Required: The href for the back arrow
    group: Object, // Required: Need name, medium avatar_image_medium_url and full_url
    
    condensedHeightEm: { type: Number, value: 3.3, readOnly: true } // used by bl-app-container
  },

  // Listeners
  _headerPanelTransform: function(e) {
    var detail = e.detail; // detail keys = [condensedHeight, height, y]
    var y = detail.y;

    // Move the top line and left nav down to accomodate the condensed space
    var newY = (y === null) ? null : Math.min(y, detail.height - detail.condensedHeight);
    this.transform((newY === null) ? '' : 'translate3d(0, ' + newY + 'px, 0)', this.$.topLine);
    this.transform((newY === null) ? '' : 'translate3d(0, ' + newY + 'px, 0)', this.$.leftNav);

    // Update the opacity of the condensed background if needed
    var condensedPercentage = newY / (detail.height - detail.condensedHeight);
    this.$.condensedBackgroundPanel.style.opacity = condensedPercentage;

    // Update the size and position of the title
    var tagScale = 0.8 + (0.2*(1 - condensedPercentage));
    var tagWrapperBottom = -1.25 + (1.55*condensedPercentage); // end up at 0.3em
    this.transform('scale(' + tagScale + ') translateZ(0)', this.$.tag);
    this.$.tagWrapper.style.bottom = tagWrapperBottom + 'em';
    
    // Fade the visual components of the tag container
    var containerOpacity = (1 - condensedPercentage);
    this.$.background.style.opacity = containerOpacity;
    this.$.divider.style.opacity = containerOpacity;
    this.$.groupInfo.style.opacity = containerOpacity;
    
    // Slide the hashtag closer to the the name
    var symbolMarginRight = 0.4*(1 - condensedPercentage);
    this.$.symbol.style.marginRight = symbolMarginRight + 'em';
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
  }

});
