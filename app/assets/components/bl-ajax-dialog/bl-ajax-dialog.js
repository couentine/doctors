/* ================================================== */
/* ===============>> BL AJAX DIALOG <<=============== */
/* ================================================== */

/*
  
  !!!  NOTE: THIS COMPONENT IS UNFINISHED. !!!

  This component displays a scrollable paper dialog filled with input items passed into it as 
  content. It places them in a form and adds save and cancel buttons to the dialog. Clicking 
  save will submit a query to via ajax to the specified url. Errors are presented in the form
  success will close the dialog.

  Styling: Set the class to one of ['orange', 'green', 'blue', 'grey']

  Events:
  - bl-ajax-dialog-cancel
  - bl-ajax-dialog-save
  - bl-ajax-dialog-success
  - bl-ajax-dialog-error

*/

Polymer({
  is: 'bl-ajax-dialog',

  properties: {
    title: String,
    url: String,
    method: { type: String, value: 'post' }, // = ['get', 'post']
    saveButtonText: { type: String, value: 'Save' },
    cancelButtonText: { type: String, value: 'Cancel' }
  },

  // Methods
  open: function() { this.$.dialog.open(); },
  close: function() { this.$.dialog.close(); },

  // Events
  cancelButtonTap: function(e) {},
  saveButtonTap: function(e) {}
});

