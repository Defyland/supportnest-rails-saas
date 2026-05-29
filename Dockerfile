FROM ruby:3.3.6-slim

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
  build-essential \
  curl \
  git \
  libsqlite3-dev \
  pkg-config \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV BUNDLE_WITHOUT=development:test \
    RAILS_ENV=production \
    SECRET_KEY_BASE=dummy

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

RUN mkdir -p storage tmp/pids log

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
