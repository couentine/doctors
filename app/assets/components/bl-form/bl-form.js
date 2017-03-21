/* ================================================== */
/* ===================>> BL FORM <<================== */
/* ================================================== */

/*

This is a generic form component designed to accept a list of field specs (refer to bl-form-field
for full documentation) and use the specs to build an iron-form which submits via ajax. 
Call submit() to submit the form. This component automatically validates the form before 
submitting the request (unless you set doNotValidate to true) and throws an error if any of the
fields are invalid.

Be sure to set modelKey to the rails key that should wrap the bl-form-field key value pairs when
the object is serialized. Example: 'report_result' or 'badge'. If you leave it blank then the 
form field key value pairs will be added at the root level of the generated object.

Events:
- bl-form-error: Fires after submit if there is a validation error, if no response is received,
  or if the success key on the response is false.
- bl-form-success: Fires after a response is received, but only if the success key is true.

## How error messages are parsed ##
  
All responses should have a success key. If success is false then this component will check for 
one of the following three keys in the reseponse:
- error_message: If present, this should be a simple string. It is passed directly on to the 
  component consumer (where it will be displayed to the users as is).
- error_messages: If present, this should be an array of string. They will be preceded by a generic
  error message and then appended into a comma delimited list.
- field_error_messages: If this is present, it should be an object with a key for each error field
  contained in the input. The form will attempt to display the errors on each field and if the 
  fields cannot be found, extra errors will be treated in the same manner as error_messages.

*/

Polymer({
  is: 'bl-form',
  
  properties: {
    action: String,
    method: { type: String, value: 'post' }, // = ['get', 'post']
    headers: Object,
    fieldSpecs: Array,
    modelKey: String, // if set, this is used by serialize() to wrap all field values
    doNotValidate: { type: Boolean, value: false }
  },
  listeners: { 
    'actionAjax.response': 'handleResponse',
    'actionAjax.error': 'handleError',
  },
  
  // Actions
  submit: function() {
    if (this.$.form.validate()) {
      // We need more control over the request contents, so we're just using the form to handle the 
      // validation. The request itself will be sent via the actionAjax
      this.$.actionAjax.body = this.serialize();
      this.$.actionAjax.generateRequest();
    } else {
      this.goError('One or more form values is invalid. Please review the error messages, fix '
        + 'the problematic values and try again.');
    }
  },
  serialize: function() {
    // Returns a json object version of all form-field values, suitable for submission to rails
    var fieldElements = this.querySelectorAll('bl-form-field');
    var returnValueInner = {}; // stores the key value pairs for all of the form fields
    var returnValue = {};
    var fieldName; var fieldValue; var outerKey; var innerKey;

    for (var i = 0; i < fieldElements.length; i++) {
      fieldName = fieldElements[i].fieldSpec.name;
      fieldValue = fieldElements[i].value();

      if (fieldName.includes('.')) {
        // If the name is 'outer.inner' convert it to be { outer: { inner: value } }
        // NOTE: For now we assume only one dot max.
        outerKey = fieldName.split('.')[0];
        innerKey = fieldName.split('.')[1];
        
        if (!returnValueInner[outerKey]) returnValueInner[outerKey] = {};
        returnValueInner[outerKey][innerKey] = fieldValue;
      } else 
        returnValueInner[fieldElements[i].fieldSpec.name] = fieldElements[i].value();
    }

    // Finally we wrap the field values in the model key if needed
    if (this.modelKey) returnValue[this.modelKey] = returnValueInner;
    else returnValue = returnValueInner;

    return returnValue;
  },
  
  // Events
  handleResponse: function(e) {
    var response = e.detail.response;
    
    if (response.success) {
      this.fire('bl-form-success', { response: response }); 
    } else {
      var errorMessage;

      if (response.field_error_messages) {
        // NOTE: Field specific errors aren't fully working yet (bl-form-field doesn't yet support 
        //       goError(); And I need to add an error clearing ability)

        var unmatchedErrorMessages = [];
        var fieldErrorMessages = response.field_error_messages; // shortcut
        var matchedElement;
        
        for (var key in fieldErrorMessages)
          if (fieldErrorMessages.hasOwnProperty(key) && fieldErrorMessages[key]) {
            matchedElement = this.$$('bl-form-field#' + key);
            if (matchedElement) matchedElement.goError(fieldErrorMessages[key]); //doesn't work yet
            else unmatchedErrorMessages.push(fieldErrorMessages[key]);
          }
        
        if (unmatchedErrorMessages.length)
          errorMessage = 'One or more values were invalid: ' + unmatchedErrorMessages.join(', ');
        else
          errorMessage = 'One or more values were invalid, please review the error messages '
            + 'on each field and try again.' 
      } else if (response.error_messages) {
        errorMessage = 'One or more errors occured: ' + unmatchedErrorMessages.join(', ');
      }

      this.goError(errorMessage, response);
    }
  }, 
  handleError: function(e) {
    this.goError('There was a problem submitting your request, please try again.');
  },
  
  //Helpers
  goError: function (errorMessage, response = undefined) {
    this.fire('bl-form-error', { errorMessage: errorMessage, response: response });
  }
});