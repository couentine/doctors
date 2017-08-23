# Badge List #

This repository stores the code that powers Badge List. It uses Mongoid (hosted now on MongoLab) for persistence and 
the Postmark gem for email. It also uses Redis (hosted now on on RedisCloud) for queueing along with Sidekiq for asynch operations.

The repo is broken into two main sections: `backend` which contains the Rails app (and all of the legacy frontend views) and `frontend` which contains the newer Polymer-powered front end app. Upon deployment the polymer app is built and copied to the assets folder of the backend so that the files can be served via Heroku and the CDN.

## Setting up your dev environment (OS X) ##

1. Install the basics: Xcode, Homebrew, Git, Github RVM, Ruby & Rails >> [Instructions here](https://www.moncefbelyamani.com/how-to-install-xcode-homebrew-git-rvm-ruby-on-mac) >> Be sure to install the current app version of ruby (2.1.2)
2. Install mongodb: [Instructions here](https://docs.mongodb.org/v3.0/tutorial/install-mongodb-on-os-x/)
3. Install redis: [Instructions here](http://jasdeep.ca/2012/05/installing-redis-on-mac-os-x/)
4. Install imagemagick >> brew install imagemagick
5. Install foreman >> gem install foreman
6. Connect to the [Github Repo](https://github.com/hankish/badgelist) and pull down the master branch
7. Setup your environment variable file (.env)
8. Run bundle install
9. Run foreman start

## Required Environment Variables ##

Key aspects of the app are managed with environment variables.  It's important to use a foreman
".env" file to store these in your local development environment and to create these in Heroku
when deploying.
- ENV['root_domain'] = badgelist.com or localhost, etc
- ENV['root_url'] = https://www.badgelist.com, etc
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
stripe_api_version=2017-06-05
stripe_enable_invoice_validation=true
twitter_consumer_key=abc123
twitter_consumer_secret=abc123
twitter_access_token=abc123
twitter_access_secret=abc123
ULTRAHOOK_API_KEY=abc123
INTERCOM_APP_ID=abc123
INTERCOM_API_KEY=abc123
WEB_CONCURRENCY=1
MIN_THREADS=1
MAX_THREADS=1
disable_all_emails=false
POSTMARK_WEBHOOK_KEY=abc123
embedly_api_key=abc123
oauth_google_client_id=abc123
oauth_google_client_secret=abc123
dev_gmail_address=knowledgestreem@gmail.com
dev_gmail_password=PASSWORD_TO_GMAIL_ACCOUNT
lti_app_name=Badge List Dev
lti_app_description=Badge List is a platform for awarding digital credentials compatible with the OpenBadge standard.
lti_unique_tool_id=badgelist-dev
bl_admin_email=app-errors@badgelist.com
```

## Running the app ##

To launch the app just run `foreman start` in terminal (that launches the app and the worker thread using the default `Procfile`. This will run both the rails app (at localhost:5000) and the polymer app (at localhost:8081). The polymer app is actually proxied via the polymer-proxy server (at localhost:8080) which exists to add CORS headers.

You'll need to use foreman to open a rails console as well (since the environment variables need to be loaded in order for the app to launch properly). To open a rails console in your terminal, navigate to the `backend` folder and run `foreman run --env ../.env rails console`. (You have to run the foreman command from backend in order to be able to use the rails command, but you then need to explicitly pass it the path to the .env file since it is located in a different directory.)

**Note:** If you are testing webhooks with external services (such as Stripe or Postmark) you will need to use `Procfile.ultrahook.dev`. That will forward `http://dev.[ultrahook_username].ultrahook.com` to `http://localhost:5000`. The ultrahook username will be the username of the account linked to the `ULTRAHOOK_API_KEY` in your `.env` file. To specify the procfile use the command below:

```
$ foreman start -f Procfile.ultrahook.dev
```

## Stripe Webhooks ##

WebhooksController is designed to accept the following events at the '/h/stripe_event' endpoint:
- customer.subscription.created
- customer.subscription.deleted
- invoice.payment_succeeded
- invoice.payment_failed

## Deployment Process ##

To deploy to staging or production you **must** use the deployment script. If you try to push directly to Heroku it will fail (because the Rails app is not located in the root of the git repo). There are also other important checks and processes which are handled by the deployment script.

To use the deployment script, navigate to the root of git repo and run the command below. (The script will walk you through the deployment process with prompts.)

```
$ ruby scripts/deploy.rb
```
