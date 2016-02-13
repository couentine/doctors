Polymer({
  is: "bl-widget-badge-count",

  properties: {
    // Required
    count: Number,
    
    // Optional
    link: {
      type: String,
      value: "#"
    },
    
    // Computed
    countDigitClass: {
      type: String,
      computed: "getDigitClass(count)"
    }
  },

  getDigitClass: function(count) {
    if (count >= 100) return "number triple-digit";
    else if (count >= 10) return "number double-digit";
    else return "number single-digit";
  }
});
