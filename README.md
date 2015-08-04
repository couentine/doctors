# Badge List #

This repository stores the code that powers Badge List. It uses Mongoid (hosted now on MongoLab) for persistence and 
the Postmark gem for email. It also uses Redis (hosted now on on RedisCloud) for queueing along with Sidekiq for asynch operations.

## Required Environment Variables ##

Key aspects of the app are managed with environment variables.  It's important to use a foreman
".env" file to store these in your local development environment and to create these in Heroku
when deploying.
- ENV['root_domain'] = badgelist.com or localhost, etc
- ENV['root_url'] = http://badgelist.com, etc
- ENV['from_email'] = app@badgelist.com or knowledgestreem@gmail.com, etc
- ENV['REDIS_PROVIDER'] = REDISCLOUD_URL

**Example ".env" file for dev environment:**
```
root_domain=localhost:5000
root_url=http://localhost:5000
from_email=knowledgestreem@gmail.com
s3_key=ABC123
s3_secret=ABC123
s3_region=us-east-1
s3_asset_url=https://s3-us-east-1.amazonaws.com
s3_bucket_name=bl-staging
stripe_key=ABC123
stripe_livemode=false
twitter_consumer_key=abc123
twitter_consumer_secret=abc123
twitter_access_token=abc123
twitter_access_secret=abc123
ULTRAHOOK_API_KEY=abc123
INTERCOM_APP_ID=abc123
INTERCOM_API_KEY=abc123
WEB_CONCURRENCY=1
MAX_THREADS=5
```

## Running foreman ##

Note that there is a seprate foreman procfile for development which will also forward webhooks
using the ultrahook client.
```
$ foreman start -f Procfile.dev
```

## Stripe Webhooks ##

WebhooksController is designed to accept the following events at the '/h/stripe_event' endpoint:
- customer.subscription.created
- customer.subscription.deleted
- invoice.payment_succeeded
- invoice.payment_failed
