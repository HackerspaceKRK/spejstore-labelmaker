FROM ruby:3.0

RUN apt-get update && \
    apt-get install -y cups-ipp-utils && \
    rm -rf /var/lib/apt/lists/*

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

CMD bundle exec ruby main.rb
