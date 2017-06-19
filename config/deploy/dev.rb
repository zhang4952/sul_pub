server 'sul-pub-dev.stanford.edu', user: 'pub', roles: %w(web db app)

Capistrano::OneTimeKey.generate_one_time_key!

set :rails_env, 'development'

set :bundle_without, %w(test).join(' ')
