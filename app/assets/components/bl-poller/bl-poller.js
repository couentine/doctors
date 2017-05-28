/* ================================================== */
/* ==================>> BL POLLER <<================= */
/* ================================================== */

/*
  
  Provide this component with the id of a poller and it displays a progress bar with the waiting
  message from the poller. It will continuously poll the poller starting at initialInterval and 
  backing off to maxInterval. After maxDuration it will stop polling and present a timeout 
  message to the user. If the poller completes, the success / failure and the poller message is 
  displayed to the user.

  Setting the pollerId property will start the poller immediately.

  This component will fire a 'bl-poller-completed' event when the poller completes, whether it is
  an error, a success or a timeout.

*/

Polymer({
  is: 'bl-poller',

  properties: {
    pollerId: { type: String, observer: '_pollerIdChanged' },
    
    // Time Settings (in milliseconds)
    initialInterval: { type: Number, value: 150 }, 
    maxInterval: { type: Number, value: 2000 }, 
    maxDuration: { type: Number, value: 300000 }, 

    intervalDoubleRate: { type: Number, value: 2 }, // how many cycles before interval doubles?

    // Computed
    isPending: { type: Boolean, value: false, computed: '_isPending(poller, isError)' },
    isSuccessful: { type: Boolean, value: false, computed: '_isSuccessful(poller, isError)' },
    isFailed: { type: Boolean, value: false, computed: '_isFailed(poller, isError)' },
    isCompleted: { type: Boolean, value: false, computed: '_isCompleted(poller)' },

    // Managed automatically
    running: { type: Boolean, value: false },
    timeout: { type: Boolean, value: false },
    progressHidden: { type: Boolean, value: true },
    poller: Object,
    pollerStarted: Date,
    errorMessage: String,
    isError: { type: Boolean, value: false },
    tries: Number
  },

  // Methods
  start: function() {
    if (!this.running) {
      this.tries = 0;
      this.pollerStarted = Date.now();
      this.running = true;
      this.$.progress.disabled = false;
      this.queryPoller();
    }
  },
  stop: function() { 
    this.running = false; 
    this.$.progress.disabled = true;
  },

  // Events
  _pollerIdChanged: function(newValue, oldVaue) { this.start(); },

  // Helpers
  queryPoller: function() {
    // This method keeps running once called until it reaches an exit condition or stop() is called
    if (this.running) {
      var self = this;

      // Calculate the next interval
      var nextInterval = Math.min(self.maxInterval,
        self.initialInterval * Math.pow(2, Math.floor(self.tries/self.intervalDoubleRate)));

      // Do the query
      $.getJSON('/p/' + self.pollerId + '.json', function(result) {
        if (result == null) 
          self.goError('The specified poller could not be found.');
        else {
          self.poller = result;
          self.tries++;
          
          // NOTE: We can't check for null because somehow progress is being changed from null to 0
          self.progressHidden = !(result.progress > 0);
          
          if (result.completed) {
            self.stop();
            self.fireCompleteEvent();
          } else if ((Date.now() - self.pollerStarted) < self.maxDuration) {
            setTimeout(function() { self.queryPoller() }, nextInterval);
          } else {
            self.timeout = true;
            self.goError('This job is taking a long time and the progress tracker has timed out, '
              + 'but the job will continue to run in the background.');
            self.fireCompleteEvent();
          }
        }
      }).error(function(e) { 
        self.goError('An error occured. (Details: ' + e + ')');
      });
    }
  },
  goError: function(errorMessage) { 
    this.errorMessage = errorMessage; 
    this.isError = true; 
    this.stop();
  },
  fireCompleteEvent: function() {
    this.fire('bl-poller-completed', { poller: this.poller, timeout: this.timeout });
  },

  // Property Computers
  _isPending: function(poller, isError) { 
    return !isError && poller && (poller.status == 'pending'); 
  },
  _isSuccessful: function(poller, isError) { 
    return !isError && poller && (poller.status == 'successful'); 
  },
  _isFailed: function(poller, isError) { 
    return !isError && poller && (poller.status == 'failed');
  },
  _isCompleted: function(poller) { 
    return poller && poller.completed;
  }
});

