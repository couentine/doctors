# Badge List #

This repository stores the code that powers Badge List. It uses Mongoid for persistence and 
the Postmark gem for email.

## Required Environment Variables ##

Key aspects of the app are managed with environment variables.  It's important to use a foreman
".env" file to store these in your local development environment and to create these in Heroku
when deploying.
- ENV['root_domain'] = badgelist.com or localhost, etc
- ENV['root_url'] = http://badgelist.com, etc
- ENV['from_email'] = app@badgelist.com or knowledgestreem@gmail.com, etc

**Example ".env" file for dev environment:**
```
root_domain=localhost:5000
root_url=http://localhost:5000
from_email=knowledgestreem@gmail.com
```