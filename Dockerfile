FROM ruby:3.4.9-slim AS base

WORKDIR /app

ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test \
    RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=1 \
    RAILS_SERVE_STATIC_FILES=1

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
  curl \
  libpq5 \
  libsqlite3-0 \
  && rm -rf /var/lib/apt/lists/*

FROM base AS build

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
  build-essential \
  git \
  libpq-dev \
  libsqlite3-dev \
  pkg-config \
  && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install \
  && rm -rf /usr/local/bundle/cache/*.gem /usr/local/bundle/ruby/*/cache

FROM base

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY . .

RUN mkdir -p storage tmp/pids log \
  && groupadd --gid 1000 rails \
  && useradd --uid 1000 --gid rails --create-home --shell /bin/bash rails \
  && chown -R rails:rails storage tmp log

USER rails:rails

ENTRYPOINT ["./bin/docker-entrypoint"]

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
