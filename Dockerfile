FROM hexpm/elixir:1.15.5-erlang-26.0.2-alpine-3.18.2 AS builder

# install build dependencies
RUN apk add --no-cache --update git build-base nodejs npm cmake

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
  mix local.rebar --force

# set build ENV
ENV MIX_ENV=prod

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# build project
COPY priv priv
COPY lib lib
RUN mix compile

# build assets
COPY assets assets
RUN mix assets.deploy

# build release
COPY config/runtime.exs config/
RUN mix release

# download pre-built sqlite db and libhnsw index
FROM alpine:3.18.3 AS artifacts
RUN apk add curl lz4
WORKDIR /export
RUN curl -O https://hexdocs-artifacts.s3.eu-central-003.backblazeb2.com/hnsw.idx
RUN curl -O https://hexdocs-artifacts.s3.eu-central-003.backblazeb2.com/wat_dev.db.lz4
RUN lz4 --rm wat_dev.db.lz4 wat.db

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM alpine:3.18.3 AS app

RUN apk add --no-cache --update openssl libstdc++ ncurses

WORKDIR /app
RUN chown nobody:nobody /app
USER nobody:nobody

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:nobody /app/_build/prod/rel/wat ./
COPY --from=artifacts --chown=nobody:nobody /export/wat.db ./
COPY --from=artifacts --chown=nobody:nobody /export/hnsw.idx ./

CMD /app/bin/wat start
