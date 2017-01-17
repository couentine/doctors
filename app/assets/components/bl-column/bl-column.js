/* ================================================== */
/* ============>> BL COLUMN COMPONENT <<============= */
/* ================================================== */

/*
  This component is CURRENTLY NOT BEING USED, but might be later.
*/

Polymer({
  is: "bl-column",

  properties: {
    field: String, // the name of the field
    type: { type: String, value: 'string' }, // = ['string', 'image']
    class: String // used to style the element, refer to bl-list.css for possible classes
  },

  json: function() {
    // This converts all of the fields to a single json object
    return { field: this.field, type: this.type, class: this.class };
  }
});
