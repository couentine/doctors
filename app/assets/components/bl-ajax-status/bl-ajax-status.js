/* ================================================== */
/* ===============>> BL AJAX STATUS <<=============== */
/* ================================================== */

/*
  
  This component is a simple overlay which displays a spinner in the lower left corner
  of the screen while an iron-ajax is in its loading state. It's ideal for conveying the status
  of an iron-ajax that may have multiple requests in flight at the same time.

  Example usage:
    <bl-ajax-status for="ironAjaxId">Text to display</bl-ajax-status>

*/

Polymer({
  is: 'bl-ajax-status',

  properties: {
    for: { type: String }, // Required. The id of the iron-ajax to watch

    ironAjax: Object // managed automatically, do not set
  },

  // Actions
  refreshStatus: function() {
    // Refreshes current status from ironAjax and fades loadingStatus in or out
    if (this.ironAjax.loading) $(this.$.loadingStatus).fadeIn();
    else $(this.$.loadingStatus).fadeOut();
  },

  // Events
  attached: function() {
    // Store a link to the iron ajax and add listeners as needed
    if (this.for) {
      this.ironAjax = document.getElementById(this.for);
      this.listen(this.ironAjax, 'iron-ajax-request', 'refreshStatus');
      this.listen(this.ironAjax, 'iron-ajax-response', 'refreshStatus');
      this.listen(this.ironAjax, 'iron-ajax-error', 'refreshStatus');
    }
  }

});

