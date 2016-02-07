Polymer({
  is: "bl-button",

  properties: {
    // Required
    type: String,
    
    // Optional
    disabled: {
      type: Boolean,
      reflectToAttribute: true,
      notify: true
    },
    link: String,
    target: String,

    // Computed
    raised: {
      type: String,
      computed: "isRaised(type)"
    }
  },

  isRaised: function(type) {
    return type == "raised";
  },
  has: function(property) {
    return (property != null) && (property != undefined)
      && ((typeof property == 'number') || (property.length > 0));
  }
});
