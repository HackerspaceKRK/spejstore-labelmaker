FROM ruby:3.0-bullseye

# throw errors if Gemfile has been modified since Gemfile.lock
RUN apt-get update
RUN apt-get install -y lpr cups-client
RUN apt-get install -y cups-ipp-utils
RUN bundle config --global frozen 1

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

CMD bundle exec ruby main.rb
