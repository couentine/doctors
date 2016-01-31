Polymer({
  is: "bl-widget-badge-count",

  properties: {
    count: Number,
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
