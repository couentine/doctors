Polymer({
  is: "bl-poller",

  properties: {
    pollerId: { type: String, observer: "_pollerIdChanged" },
    
    // Time Settings (in milliseconds)
    initialInterval: { type: Number, value: 150 }, 
    maxInterval: { type: Number, value: 2000 }, 
    maxDuration: { type: Number, value: 300000 }, 

    intervalDoubleRate: { type: Number, value: 2 }, // how many cycles before interval doubles?

    // Managed automatically
    running: Boolean,
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
      this.queryPoller;
    }
  },
  stop: function() { this.running = false; },

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
      $.getJSON("/p/" + self.pollerId + ".json", function(result) {
        if (result == null) 
          self.goError("The specified poller could not be found.");
        else {
          self.poller = result;
          self.tries++;
          
          if (result.completed) 
            self.stop();
          else if ((Date.now() - self.pollerStarted) < self.maxDuration)
            setTimeout(function() { self.queryPoller() }, nextInterval); 
          else
            self.goError("The maximum waiting interval has elapsed.");
        }
      }).error(function(e) { 
        self.goError("An error occured. (Details: " + e + ")");
      });
    }
  },
  goError: function(errorMessage) { 
    this.errorMessage = errorMessage; 
    this.isError = true; 
    this.stop();
  }
});

