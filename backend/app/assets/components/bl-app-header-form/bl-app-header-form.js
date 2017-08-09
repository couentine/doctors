Polymer({
  is: "bl-app-header-form",

  properties: {
    title: { type: String }, // Required: The page title
    background: { type: String, observer:'_backgroundChanged' },
    condensedBackground: { type: String, observer:'_condensedBackgroundChanged' },
    headerColor: { type: String, observer:'_headerColorChanged' },
    selectionBarFor: String, // Set to id of a bl-list to use the header as the selection bar
    count: Number, // this is set by the bl-list if selectionBarFor is set
    countNounSingular: String, // singular noun to use in title bar when count is visible
    countNounPlural: String, // optional: leave this blank to simply add an 's' to the singular
    
    condensedHeightEm: { type: Number, value: 5, readOnly: true }, // used by bl-app-container

    // Computed
    showCount: { type: Boolean, computed: '_showCount(count)' },
    countText: { type: Boolean, computed: '_countText(count)' }
  },

  // Listeners
  _headerPanelTransform: function(e) {
    var detail = e.detail; // detail keys = [condensedHeight, height, y]
    var y = detail.y;

    var newY = (y === null) ? null : Math.min(y, detail.height - detail.condensedHeight);

    // Move the top line down to accomodate the condensed space
    this.transform((newY === null) ? '' : 'translate3d(0, ' + newY + 'px, 0)', this.$.topLine);

    // Update the opacity of the condensed background if needed
    var condensedPercentage = newY / (detail.height - detail.condensedHeight);    
    this.$.condensedBackgroundPanel.style.opacity = condensedPercentage;

    // Change the title color if needed
    if (condensedPercentage == 1.0) this.$.title.style.color = 'white';
    else this.$.title.style.color = '';
  },

  // Events
  attached: function() {
    // Listen for the transform event
    var self = this;
    document.addEventListener('paper-header-transform', function(e) {
      self._headerPanelTransform(e);
    });

    // Register ourselves as the selection bar for the bl-list if needed
    if (this.selectionBarFor && document.querySelector("#" + this.selectionBarFor))
      document.querySelector("#" + this.selectionBarFor).selectionBar = this;
  },
  ready: function() {
    // Notify bl-app-container of the condensedHeaderHeight
    this.fire('bl-app-header-content-ready', { condensedHeightEm: this.condensedHeightEm });
  },

  // Observers
  _condensedBackgroundChanged: function(newValue, oldValue) {
    // Update the css variable that controls background any time the value changes
    this.customStyle['--condensed-background'] = newValue;
    this.updateStyles();
  },
  _headerColorChanged: function(newValue, oldValue) {
    // Update the css variable that controls background any time the value changes
    this.customStyle['--header-color'] = newValue;
    this.updateStyles();
  },
  
  // Computed Properties
  _showCount: function(count) { return count > 0; },
  _countText: function(count) {
    if (count == 1) return count + ' ' + this.countNounSingular + ' selected'; 
    else if (this.countNounPlural) return count + ' ' + this.countNounPlural + ' selected'; 
    else return count + ' ' + this.countNounSingular + 's selected'; 
  }
});
