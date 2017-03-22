/* ================================================== */
/* ================>> BL FORM FIELD <<=============== */
/* ================================================== */

/*

  This displays a form field based on a field spec object with the following keys:
  - key: Required. Unique in the form, used as the form field id
  - name: Required. The input's name property, important for how the information is submitted
  - type: Required. One of: String, Date, 'BSON::ObjectId', hidden
  - label: Required. The user-displayed field label.
  - element: Optional. Name of element to use (if left out a default is picked based on type)
    valid elements = paper-input, date-picker, paper-dropdown-menu, hidden
  - value: Optional. Used to set the initial value of the element.
  - options: Required for paper-dropdown-menu elements. Array of options, each option should be 
    a hash with two keys: label and value
  - dependent_key: Set this is this is a dropdown dependent on another dropdown. Then also set...
  - dependent_options: Set this instead of options for a dependent dropdown. It should be an object
    with one key for each possible dependent key value and values equal to a list of options.

*/

Polymer({
  is: 'bl-form-field',

  properties: {
    fieldSpec: { type: Object, observer: '_fieldSpecChanged' },
    errorMessage: { type: String, value: null, notify: true },
    invalid: { type: Boolean, value: false, notify: true },
    options: Array,

    // Automatically managed
    dependentListbox: Object,
    dependentOptions: Object,
    dependentListenerInitialized: { type: Boolean, value: false },
    
    // Computed properties
    isPaperInput: { type: Boolean, computed: '_isPaperInput(fieldSpec)' },
    isDatePicker: { type: Boolean, computed: '_isDatePicker(fieldSpec)' },
    isPaperDropdownMenu: { type: Boolean, computed: '_isPaperDropdownMenu(fieldSpec)' },
    isHidden: { type: Boolean, computed: '_isHidden(fieldSpec)' }
  },

  // Actions
  value: function() { 
    if (this.isPaperInput || this.isDatePicker) 
      return this.$$('paper-input').value;
    else if (this.isPaperDropdownMenu) {
      if (this.$$('paper-listbox').selectedItem)
        return this.$$('paper-listbox').selectedItem.value;
      else
        return null;
    } else if (this.isHidden)
      return this.$$('input').value;
    else
      return null;
  },

  // Events
  attached: function() {
    // If we have dependent options, then listen for changes of the dependent dropdown
    if (this.dependentOptions && this.fieldSpec.dependent_key) {
      var self = this;
      
      document.addEventListener('dom-change', function() {
        self.dependentListbox = document.querySelector('paper-listbox#'
          + self.fieldSpec.dependent_key);
        
        if (self.dependentListbox && !self.dependentListenerInitialized) {
          self.dependentListbox.addEventListener('iron-select', function(e) {
            self.options = self.dependentOptions[e.detail.item.value];
          });
          self.dependentListenerInitialized = true;
        }
      });
    }

    if (this.fieldSpec.required && !this.errorMessage)
      this.errorMessage = 'This field is required';
  },
  _fieldSpecChanged: function(newValue, oldValue) {
    if (newValue.options && newValue.options.length) this.options = newValue.options;
    else this.options = [];

    if (newValue.dependent_options) this.dependentOptions = newValue.dependent_options;
    else this.dependentOptions = null;
  },

  // Computed properties
  _isPaperInput: function(fieldSpec) { 
    return (fieldSpec.element == 'paper-input') 
      || ((fieldSpec.type == 'String') && (!fieldSpec.element || (fieldSpec.element == '')));
  },
  _isDatePicker: function(fieldSpec) { 
    return (fieldSpec.element == 'date-picker') || (fieldSpec.type == 'Date');
  },
  _isPaperDropdownMenu: function(fieldSpec) { 
    return (fieldSpec.element == 'paper-dropdown-menu') || (fieldSpec.type == 'BSON::ObjectId');
  },
  _isHidden: function(fieldSpec) { return fieldSpec.type == 'hidden'; }
});
