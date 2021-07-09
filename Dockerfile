FROM ruby:2.4.5-stretch

# configure for 12-factor deployment (https://12factor.net/)
ENV RAILS_ENV production
ENV RAILS_LOG_TO_STDOUT true
ENV RAILS_SERVE_STATIC_FILES true

# NOTE: This is a temporary secret key base to make the asset compilation passed.
ENV TEMP_SECRET_KEY_BASE dummy

# Set an environment variable to store where the app is installed inside the Docker image
ENV INSTALL_PATH /mssng-portal

# Install Node.js and Yarn
# NOTE:
#  1. Asset precompiler requires a node.js executable called "node" that's at least version 4 and Yarn.
#  2. This block also cleans up the site packages and automatically removes APT cache to reduce the image usage.
RUN curl -sL https://deb.nodesource.com/setup_6.x -o nodesource_setup.sh \
  && bash nodesource_setup.sh \
  && apt-get update -q \
  && apt-get install -qq -y nodejs --fix-missing --no-install-recommends \
  && npm install -g yarn@1.7.0 \
  && apt-get autoremove -q \
  && apt-get clean -q \
  && rm -rf /var/lib/apt/lists/*

# Set up the install path.
RUN mkdir -p $INSTALL_PATH
WORKDIR $INSTALL_PATH

COPY Gemfile $INSTALL_PATH/Gemfile
COPY Gemfile.lock $INSTALL_PATH/Gemfile.lock
RUN bundle install --jobs=4

# Doing this after `bundle install` helps speed up subsequent builds due to improved Docker layer caching
COPY . .

# Provide dummy data to Rails so it can pre-compile assets.
RUN SECRET_KEY_BASE=$TEMP_SECRET_KEY_BASE bundle exec rake assets:clean
RUN SECRET_KEY_BASE=$TEMP_SECRET_KEY_BASE bundle exec rake assets:precompile

EXPOSE 3000

CMD bash -c "rails db:migrate && bundle exec rails server -b 0.0.0.0"