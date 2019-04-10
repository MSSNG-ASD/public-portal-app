source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end


# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 5.1.5'
# Use sqlite3 as the database for Active Record
gem 'sqlite3'
# Use mysql2 as the database for entrez
gem 'mysql2', '~> 0.4.10'
# Use Puma as the app server
gem 'puma', '~> 3.7'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.2'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
# disable turbolinks to avoid js loading problems
# gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.5'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development
# Authentication and Authorization with devise/omniauth/google-oauth2
gem 'devise'
gem 'omniauth-google-oauth2'
# Revoke token
gem 'http'
# Bigquery
gem 'google-cloud-bigquery', :require => 'google/cloud/bigquery'
# Bootstrap 4
gem 'bootstrap', '~> 4.0.0'
gem 'jquery-rails'
# MSSNG look and feel
gem 'font-awesome-rails'
gem 'awesome-share-buttons', github: 'evansobkowicz/awesome-share-buttons'
# resource level authorization
gem 'pundit'
# easier forms
gem 'simple_form'
# better select
gem 'select2-rails', '3.5.9.3'
# needed for character by character searching
gem 'kaminari'
# better tables
gem 'jquery-datatables'
# for copying content to the clipboard
gem 'clipboard-rails'
# igv html5 viewer
gem 'igv-rails', '1.0.9.10'
# xlsx files
gem 'rubyzip', '>= 1.2.1'
gem 'axlsx', git: 'https://github.com/randym/axlsx.git', ref: 'c8ac844'
gem 'axlsx_rails'
# email errors
gem 'exception_notification'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '~> 2.13'
  gem 'selenium-webdriver'
  # unit tests
  gem 'rspec-rails', '~> 3.5'
  # acceptance tests
  gem 'cucumber-rails', require: false
  # easier test matchers https://github.com/thoughtbot/shoulda-matchers
  gem 'shoulda-matchers', git: 'https://github.com/thoughtbot/shoulda-matchers.git', branch: 'rails-5'
  # fake objects for testing
  gem 'factory_bot_rails'
end

group :test do
  # cleaning databases between runs
  gem 'database_cleaner'
  # controller testing
  gem 'rails-controller-testing'
  # open browser on failed tests
  gem 'launchy'
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
  # preview email in the browser instead of sending it
  gem "letter_opener"
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

gem 'stackdriver'
gem 'concurrent-ruby-edge', '0.3.1', require: 'concurrent-edge'