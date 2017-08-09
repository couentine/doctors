/* ================================================== */
/* ==================>> BL BUTTON <<================= */
/* ================================================== */

/*
  
  Use this to create all buttons to match the app style.

  The preferred way to use this element is to set the link property to a URL, which will wrap
  the button in an anchor tag. This is preferred for inter-page navigation because it lets users
  use browser functionality such as opening links in new tabs.

  If you need to call a js function instead, then leave the link parameter blank and 
  set the js property instead. It should be set to a string of js to eval.
  >> Ex: <bl-button js="runThis()">

*/

Polymer({
  is: "bl-button",

  properties: {
    // Required
    type: String,
    
    // Optional
    disabled: { type: Boolean, reflectToAttribute: true, notify: true },
    link: { type: String, observer: '_linkChanged' }, // Only set this OR js, don't set both
    js: String, // Javascript to eval on button tap (ex: 'doClick()')

    target: String,
    background: { type: String, observer:'_backgroundChanged' },
    color: { type: String, observer:'_colorChanged' },

    // Computed
    isRaised: { type: Boolean, computed: "_isRaised(type)" },
    
    // Auto Set
    hasLink: { type: Boolean, value: false }
  },

  // Observers
  _linkChanged: function(newValue, oldValue) {
    this.hasLink = (newValue != undefined) && (newValue != null) && (newValue.length > 0);
  },
  _backgroundChanged: function(newValue, oldValue) {
    // Update the css variable that controls background any time the value changes
    this.customStyle['--background'] = newValue;
    this.updateStyles();
  },
  _colorChanged: function(newValue, oldValue) {
    // Update the css variable that controls color any time the value changes
    this.customStyle['--color'] = newValue;
    this.updateStyles();
  },

  // Actions
  buttonTap: function() {
    if (this.js) eval(this.js);
  },

  // Computed
  _isRaised: function(type) { return type == "raised"; }
});
