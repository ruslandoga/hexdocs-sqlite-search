FROM hexpm/elixir:1.15.5-erlang-26.0.2-alpine-3.18.2 AS builder

# install build dependencies
RUN apk add --no-cache --update git build-base

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
COPY config/config.exs config/
RUN mix deps.compile

# build project
COPY Makefile Makefile
COPY c_src c_src
COPY lib lib
RUN mix compile

# build release
COPY config/runtime.exs config/
RUN mix release

# download pre-built sqlite db index
FROM alpine:3.18.2 AS artifacts
RUN apk add curl zstd
WORKDIR /export
RUN curl -O https://hexdocs-artifacts.s3.eu-central-003.backblazeb2.com/wat2.db.zst
RUN zstd --rm wat2.db.zst -o wat.db -d

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM alpine:3.18.2 AS app

RUN apk add --no-cache --update openssl libstdc++ ncurses

WORKDIR /app
# RUN chown nobody:nobody /app
# USER nobody:nobody

# Only copy the final release from the build stage
# COPY --from=builder --chown=nobody:nobody /app/_build/prod/rel/wat ./
# COPY --from=artifacts --chown=nobody:nobody /export/wat.db ./

COPY --from=builder /app/_build/prod/rel/wat ./
COPY --from=artifacts /export/wat.db ./

CMD /app/bin/wat start
