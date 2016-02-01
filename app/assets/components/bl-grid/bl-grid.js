Polymer({
  is: "bl-grid",

  properties: {
    class: String,
    nextPageUrl: String,
    nextPage: Number,
    groups: {
      type: Array,
      value: function() {  return []; },
      reflectToAttribute: true,
      notify: true
    }
  },

  ready: function() {
    // this.customStyle["--item-background-color"] = "rgb(189,189,189)";
    // this.updateStyles();
  },

  has: function(property) {
    return (property != null) && 
      ((typeof property == 'number') || (property.length > 0));
  },
  equals: function(property, value) {
    return property == value;
  },

  loadNextPage: function() {
    $.getJSON(this.nextPageUrl + this.nextPage, function(groupsResult) {
      if (groupsResult) {
        var groups = groupsResult.groups;
        var gridElement = document.getElementsByTagName('bl-grid')[0];

        // Add all of the new groups to the array (this will auto update the dom-repeat)
        for (var i = 0; i <= groups.length; i++) 
          gridElement.push('groups', groups[i]);
        
        // Store the new value of nextPage
        gridElement.nextPage = groupsResult.next_page;
      }
    });
  }
});
