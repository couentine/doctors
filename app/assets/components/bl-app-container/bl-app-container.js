/* ================================================== */
/* ==============>> BL APP CONTAINER <<============== */
/* ================================================== */

/*
  
  This is the primary container for the all internal app pages. It contains the scroll header panel.
  There will only be one of these on the page, with id="appContainer". You can access the app 
  container from javascript inside or outside of polymer by using the appContainer variable 
  which is set automatically by the app layout javascript.

  USEFUL CONTAINER ACTIONS (Refer to each method's comments for documentation):
  - appContainer.addToast(...)
  - appContainer.openAlertDialog(...)
  - appContainer.openPollerDialog(...)
  - appContainer.openWaitingDialog(...)
  - appContainer.closeWaitingDialog()

*/

Polymer({
  is: "bl-app-container",

  properties: {
    // Required
    assetPaths: { type: Object },
    currentUser: { type: Object },
    
    // Optional
    pageBackground: { type: String, value:'#FFFFFF', observer:'_pageBackgroundChanged' },
    whiteHeaderText: { type: Boolean, value: false },
    whiteBodyText: { type: Boolean, value: false },
    hideCondensedHeader: { type: Boolean, value: false }, // Scroll away header after condensing
    hideLeftNav: { type: Boolean, value: false },
    hideRightNav: { type: Boolean, value: false },
    hideIntercom: { type: Boolean, value: false },
    
    // Computed
    condensedHeaderHeightPx: { type: Number, 
      computed: '_condensedHeaderHeightPx(condensedHeaderHeightEm, screenWidth)' },

    // Automatically Set
    condensedHeaderHeightEm: { type: Number, value: 3 }, // set from child app header element
    screenWidth: { type: Number, readOnly: true },
    dialogConfirmFunction: Object,
    dialogDismissFunction: Object,

    // Font Size Contant (Maps from screenWidth to fontSize)
    fontSizeBreakpoints: { type: Array, value: function() { return [
      { minWidth: 0, fontSize: 14 },
      { minWidth: 480, fontSize: 16 },
      { minWidth: 840, fontSize: 18 }
    ]; } }
  },

  // Listeners
  listeners: {
    'headerPanel.paper-header-transform': '_headerPanelTransform',
    'bl-app-header-content-ready': '_appHeaderContentReady',
    'pollerDialogPoller.bl-poller-completed' : '_pollerCompleted'
  },
  _headerPanelTransform: function(e) {
    var detail = e.detail; // detail keys = [condensedHeight, height, y]
    var y = detail.y;

    // Move the navbars down to accomodate the condensed space
    var newY = (y === null) ? null : Math.min(y, detail.height - detail.condensedHeight);
    this.transform((newY === null) ? '' : 'translate3d(0, ' + newY + 'px, 0)', this.$.leftNav);
    this.transform((newY === null) ? '' : 'translate3d(0, ' + newY + 'px, 0)', this.$.rightNav);

    // If header is condensed then add the shadow, otherwise remove it
    if (this.$.headerPanel.headerState == Polymer.PaperScrollHeaderPanel.HEADER_STATE_CONDENSED)
      $(this.$.appHeader).addClass('elevated');
    else
      $(this.$.appHeader).removeClass('elevated');
  },
  _appHeaderContentReady: function(e) {
    // Pull the condensed header from the bl-app-header-* element
    this.condensedHeaderHeightEm = e.detail.condensedHeightEm;
  },

  // Events
  ready: function() {
    // We need to manually fix any paper drowndown menus if present
    // Details here: https://github.com/PolymerElements/paper-dropdown-menu/issues/10
    // NOTE: This doesn't seem to work in a normal listener
    document.addEventListener('WebComponentsReady', function() {
      var paper_dropdowns = document.querySelectorAll('paper-dropdown-menu');
      for(var a = 0; a < paper_dropdowns.length; a++) {
        paper_dropdowns[a].disabled = false;
        paper_dropdowns[a].querySelector('paper-input').disabled = false;
        paper_dropdowns[a].querySelector('paper-menu-button').disabled = false;
        paper_dropdowns[a].querySelector('iron-dropdown').disabled = false;
      }
    });
  },
  attached: function() { 
    // Update the screenWidth property anytime the window is resized
    var self = this;
    $(window).on('resize', function() { 
      self._setScreenWidth($(window).width()); 
    });
    self._setScreenWidth($(window).width()); // set it on page load as well

    if (this.hideIntercom) this.tryToHideIntercom();
  },
  dialogConfirm: function() {
    if (this.dialogConfirmFunction) this.dialogConfirmFunction();
  },
  dialogDismiss: function() {
    if (this.dialogDismissFunction) this.dialogDismissFunction();
  },
  _pollerCompleted: function(e) {
    $(this.$.pollerDialogButtons).removeClass('collapsed');
  },

  // Observers
  _pageBackgroundChanged: function(newValue, oldValue) {
    // Update the css variable that controls background any time the value changes
    this.customStyle['--page-background'] = newValue;
    this.updateStyles();
  },

  // Actions
  addToast: function(text, type, autoCloseAfter) {
    // Displays new toast item in the app toast container
    // Leave type or autoCloseAfter blank to use the default
    this.getContentChildren('#toastContainer')[0].addToast(text, type, autoCloseAfter);
  },
  openAlertDialog: function(options) {
    // Shows the standard alert dialog. The following options should be included:
    // - color = ['orange', 'green', 'blue', 'grey', 'red']
    // - title = The title of the dialog
    // - body = (Optional) The body text
    // - confirm = { text: 'Accept', action: function(){} } >> leave out property to hide button
    // - dismiss = { text: 'Cancel', action: function(){} } >> leave out property to hide button

    // First set the basic properties
    this.$.alertDialog.noCancelOnEscKey = false; // restore this (overridden from modal default)
    this.setDialogColor(options.color);
    this.$.alertDialogTitle.innerHTML = options.title;
    if (options.body) {
      this.$.alertDialogBody.innerHTML = options.body;
      this.$.alertDialogBody.hidden = false;
    } else {
      this.$.alertDialogBody.innerHTML = '';
      this.$.alertDialogBody.hidden = true;
    }

    // Then set up the buttons
    if (options.confirm) {
      this.$.alertDialogConfirmText.innerHTML = options.confirm.text;
      this.$.alertDialogConfirm.hidden = false;
      this.dialogConfirmFunction = options.confirm.action;
    } else {
      this.$.alertDialogConfirmText.innerHTML = '';
      this.$.alertDialogConfirm.hidden = true;
      this.dialogConfirmFunction = null;
    }
    if (options.dismiss) {
      this.$.alertDialogDismissText.innerHTML = options.dismiss.text;
      this.$.alertDialogDismiss.hidden = false;
      this.dialogDismissFunction = options.dismiss.action;
    } else {
      this.$.alertDialogDismissText.innerHTML = '';
      this.$.alertDialogDismiss.hidden = true;
      this.dialogDismissFunction = null;
    }

    this.$.alertDialog.open();
  },
  openPollerDialog: function(pollerId, options) {
    // Shows the standard poller dialog. The following options should be included:
    // - color = ['orange', 'green', 'blue', 'grey', 'red']
    // - title = The title of the dialog
    // - confirm = { text: 'Accept', action: function(){} } >> leave out property to hide button
    // - dismiss = { text: 'Cancel', action: function(){} } >> leave out property to hide button
    // - showButtonsOnLoad = (Default = false) Unless set to true, 
    //                                         the buttons are hidden until poller completes

    // First set the basic properties
    this.setDialogColor(options.color);
    this.$.pollerDialogTitle.innerHTML = options.title;

    // Then set up the buttons
    if (options.confirm) {
      this.$.pollerDialogConfirmText.innerHTML = options.confirm.text;
      this.$.pollerDialogConfirm.hidden = false;
      this.dialogConfirmFunction = options.confirm.action;
    } else {
      this.$.pollerDialogConfirmText.innerHTML = '';
      this.$.pollerDialogConfirm.hidden = true;
      this.dialogConfirmFunction = null;
    }
    if (options.dismiss) {
      this.$.pollerDialogDismissText.innerHTML = options.dismiss.text;
      this.$.pollerDialogDismiss.hidden = false;
      this.dialogDismissFunction = options.dismiss.action;
    } else {
      this.$.pollerDialogDismissText.innerHTML = '';
      this.$.pollerDialogDismiss.hidden = true;
      this.dialogDismissFunction = null;
    }
    if (options.showButtonsOnLoad) $(this.$.pollerDialogButtons).removeClass('collapsed');
    else $(this.$.pollerDialogButtons).addClass('collapsed');

    this.$.pollerDialogPoller.pollerId = pollerId; // This starts the poller query
    this.$.pollerDialog.open();
  },
  openWaitingDialog: function(options) {
    // Shows the standard waiting dialog. The following options should be included:
    // - color = ['orange', 'green', 'blue', 'grey', 'red']
    // - title = The title of the dialog

    this.setDialogColor(options.color);
    this.$.waitingDialogTitle.innerHTML = (options.title) ? options.title : 'Waiting...';
    this.$.waitingDialog.open();
  },
  closeWaitingDialog: function() {
    this.$.waitingDialog.close();
  },

  // Computed Properties
  _condensedHeaderHeightPx: function(condensedHeaderHeightEm, screenWidth) {
    return this.fontSizeForScreenWidth(screenWidth) * condensedHeaderHeightEm;
  },

  // Helpers
  fontSizeForScreenWidth: function(screenWidth) {
    // Returns integer value of font size in pixels for the specified screen width
    // Refers to fontSizeBreakpoints

    var returnValue = 14; // default value is 14 if breakpoints haven't been loaded yet
    var breakpoints = this.fontSizeBreakpoints; // shortcut for code brevity

    if (breakpoints && breakpoints.length)
      for (var i=0; (i < breakpoints.length) && (screenWidth >= breakpoints[i].minWidth); i++)
        returnValue = breakpoints[i].fontSize;
    
    return returnValue;
  },
  tryToHideIntercom: function(tryCount) {
    var self = this;

    if (!tryCount) tryCount = 1;

    if (document.querySelector('#intercom-container'))
      document.querySelector('#intercom-container').hidden = true;
    else if (tryCount < 100)
      setTimeout(function() { self.tryToHideIntercom(tryCount + 1); }, 100);
  },
  setDialogColor: function(color) {
    // This is primarily called by the standard dialog functions
    // It sets all of the appropriate css variables to match the specified color
    // Defaults to orange
    if (color == 'blue') { // material light blue
      this.customStyle['--dialog-50-color'] = '#E1F5FE';
      this.customStyle['--dialog-100-color'] = '#B3E5FC';
      this.customStyle['--dialog-300-color'] = '#4FC3F7';
      this.customStyle['--dialog-600-color'] = '#039BE5';
    } else if (color == 'green') {
      this.customStyle['--dialog-50-color'] = '#F1F8E9';
      this.customStyle['--dialog-100-color'] = '#C8E6C9';
      this.customStyle['--dialog-300-color'] = '#AED581';
      this.customStyle['--dialog-600-color'] = '#7CB342';
    } else if (color == 'grey') {
      this.customStyle['--dialog-50-color'] = '#FAFAFA';
      this.customStyle['--dialog-100-color'] = '#F5F5F5';
      this.customStyle['--dialog-300-color'] = '#E0E0E0';
      this.customStyle['--dialog-600-color'] = '#757575';
    } else if (color == 'red') {
      this.customStyle['--dialog-50-color'] = '#FFEBEE';
      this.customStyle['--dialog-100-color'] = '#FFCDD2';
      this.customStyle['--dialog-300-color'] = '#E57373';
      this.customStyle['--dialog-600-color'] = '#E53935';
    } else { // default = orange
      this.customStyle['--dialog-50-color'] = '#FFF3E0';
      this.customStyle['--dialog-100-color'] = '#FFE0B2';
      this.customStyle['--dialog-300-color'] = '#FFB74D';
      this.customStyle['--dialog-600-color'] = '#FB8C00';
    }
    this.updateStyles();
  }
});
