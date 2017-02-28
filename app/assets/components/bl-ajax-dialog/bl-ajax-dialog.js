/* ================================================== */
/* ===============>> BL AJAX DIALOG <<=============== */
/* ================================================== */

/*

This component displays a scrollable paper dialog filled with input items passed into it as 
content. It places them in a form and adds save and cancel buttons to the dialog. Clicking 
save will submit a query to via ajax to the specified url. Errors are presented in the form
success will close the dialog.

Styling: Set the class to one of ['orange', 'green', 'blue', 'grey']

Events:
- bl-ajax-dialog-success
- bl-ajax-dialog-error

*/

Polymer({
  is: 'bl-ajax-dialog',
  
  properties: {
    title: String,
    action: {
      type: String,
    }, 
    method: { type: String, value: 'post' }, // = ['get', 'post']
    headers: Object,
    saveButtonText: { type: String, value: 'Save' },
    cancelButtonText: { type: String, value: 'Cancel' },
    loading: { type: Boolean, value: false },
    isError: { type: Boolean, value: false },
    errorText: String
  },
  listeners: { 
    'form.iron-form-response': 'handleResponse',
    'form.iron-form-error': 'handleError'          
  },
  
  // Methods
  open: function() { this.$.dialog.open(); },
  close: function() { this.$.dialog.close(); },
  
  // Handles the json returned by rails
  handleResponse: function(e) {
    //check if submission was successfull
    var response = e.detail.response;
    if (response.success) {
      this.fire('bl-ajax-dialog-success', response.group_tag); 
      this.close();
    } else {
      var errors = response.field_error_messages;
      this.getContentChildren().forEach(function(inputElement) {
        var fieldName;
        //Regex to extract input name between square brackets.
        if (inputElement.name.match(/\[(.*?)\]/)) {
          fieldName = inputElement.name.match(/\[(.*?)\]/)[1];
        } else {
          fieldName = inputElement.name;
        }
        if (errors[fieldName]) {
          inputElement.errorMessage = errors[fieldName][0].join('. ');
          inputElement.invalid = true;
        }
      });
      this.goError('There was a problem saving the record. ' 
        + 'Please review the errors below and try again.');
      this.fire('bl-ajax-dialog-error', response.group_tag);
    }
    this.loading = false;
  }, 
  handleError: function(e) {
    this.loading = false;
    this.goError('There was a problem with the request, please try again.');
  },
  
  // Events
  cancelButtonTap: function(e) {
    this.clearError();
    this.close();
  },
  saveButtonTap: function(e) {
    this.clearError();
    this.loading = true;
    this.$.form.submit();
  },


  //Helpers
  goError: function (errorText) {
    this.isError = true;
    this.errorText = errorText;
  },
  clearError: function () {
    this.getContentChildren().forEach(function(inputElement) {
      inputElement.invalid = false;
    });
    this.isError = false;
    this.errorText = '';
  }
});