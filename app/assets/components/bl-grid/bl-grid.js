Polymer({
  is: "bl-grid",

  properties: {
    class: String,
    url: String,
    nextPage: Number,
    pageParam: String,
    groups: Array
  },

  has: function(objectArray) {
    return (objectArray != null) && (objectArray.length > 0);
  },
  equals: function(property, value) {
    return property == value;
  },
  hasNextPage: function() {
    return this.nextPage != null;
  }
});
