Polymer({
  is: "bl-html-echo",

  properties: {
    html: {
      type: String,
      observer: "_htmlChanged"
    }
  },

  _htmlChanged: function(newValue, oldValue) {
    // WARNING: potential XSS vulnerability if `html` comes from an untrusted source
    this.innerHTML = newValue;
  }
});
