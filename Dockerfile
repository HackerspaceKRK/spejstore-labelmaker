FROM ruby:2.7

RUN apt-get update && \
    apt-get install -y cups-ipp-utils && \
    rm -rf /var/lib/apt/lists/*

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1
RUN gem install bundler:1.17.2

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

CMD bundle exec ruby main.rb
