FROM ruby:3.3.6-slim

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
  build-essential \
  curl \
  git \
  libpq-dev \
  libsqlite3-dev \
  pkg-config \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV BUNDLE_WITHOUT=development:test \
    RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=1 \
    RAILS_SERVE_STATIC_FILES=1

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

RUN mkdir -p storage tmp/pids log \
  && groupadd --gid 1000 rails \
  && useradd --uid 1000 --gid rails --create-home --shell /bin/bash rails \
  && chown -R rails:rails storage tmp log

USER rails:rails

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
