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
    url: {
      type: String,
      notify: true,
      reflectToAttribute: true
    }, 
    method: { type: String, value: 'post' }, // = ['get', 'post']
    headers: String,
    saveButtonText: { type: String, value: 'Save' },
    cancelButtonText: { type: String, value: 'Cancel' },
    loading: Boolean
  },
  observers: [
  // Note that this function  will not fire until *all* parameters
  // given have been set to something other than `undefined`
  'attributesReady(url)'
  ],
  
  attributesReady: function(url) {
    this.$.form.action = url;
  },
  
  // Methods
  open: function() { this.$.dialog.open(); },
  close: function() { this.$.dialog.close(); },
  
  // Handles the json returned by rails
  handleSubmit: function(data) {
    this.fire('tagUpdate', data.detail.response.group_tag);
    console.log(data.detail.response.group_tag);
  }, 
  
  // Events
  cancelButtonTap: function(e) {
    this.close();
  },
  saveButtonTap: function(e) {
    
    this.$.form.headers = JSON.parse(this.headers);
    this.$.form.submit();
    
    this.listen(this.$.form, 'iron-form-response', 'handleSubmit')
    //this.close();
  }
});

