source 'https://rubygems.org'

gem 'grape', '~> 1.0'
gem 'rails', '~> 4.2.10'
gem 'responders', '~> 2.4'

# Use sass-powered bootstrap
gem 'bootstrap-sass', '~> 3.3.7'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '~> 3.0'
# JS Runtime. See https://github.com/rails/execjs#readme for more supported runtimes
gem 'therubyracer'

gem 'mysql2', '~> 0.4.9'

gem 'nokogiri', '>= 1.7.1'

gem 'activerecord-import'
# To use ActiveModel has_secure_password
# gem 'bcrypt-ruby', '~> 3.0.0'
gem 'bibtex-ruby'
gem 'bio'
gem 'citeproc-ruby', '~> 1.0'
gem 'config'
gem 'csl-styles', '~> 1.0'
gem 'delayed_job'
gem 'delayed_job_active_record'
gem 'dotiw'
gem 'faraday'
gem 'high_voltage'
gem 'htmlentities', '~> 4.3'
gem 'httpclient', '~> 2.7'
# To use Jbuilder templates for JSON
gem 'jbuilder'
gem 'jquery-rails'
gem 'kaminari'
gem 'libv8'
gem 'okcomputer' # for monitoring
gem 'paper_trail'
gem 'parallel'
gem 'pry-rails'
gem 'pubmed_search'
gem 'rest-client'
gem 'savon', '~> 2.11'
gem 'simple_form'
gem 'turnout'
gem 'whenever', require: false
gem 'yaml_db'

# http://stackoverflow.com/questions/35893584/nomethoderror-undefined-method-last-comment-after-upgrading-to-rake-11
# same error in travis build with rake v12.0.0, so I chose to pin rake back
gem 'rake', '~> 11.3.0'

# -------------------
gem 'honeybadger', '~> 2.0'
gem 'retina_tag'

group :development, :test do
  gem 'dlss_cops' # includes rubocop
  gem 'rails_db'
end

group :development do
  gem 'pry-doc'
  gem 'thin' # app server
  gem 'web-console', '~> 2.0'
end

group :test do
  gem 'capybara'
  gem 'coveralls', '~> 0.8', require: false
  gem 'database_cleaner'
  gem 'equivalent-xml'
  gem 'factory_girl_rails', '~> 4.0'
  gem 'rspec-rails', '~> 3.0'
  gem 'simplecov', '~> 0.13', require: false
  gem 'single_cov'
  gem 'vcr'
  gem 'webmock'
end

group :deployment do
  gem 'capistrano'
  gem 'capistrano-passenger'
  gem 'capistrano-rails'
  gem 'capistrano-shell'
  gem 'dlss-capistrano'
end
