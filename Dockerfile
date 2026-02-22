# ==============================================================================
# Event Broadcast Service Dockerfile
# Multi-stage build for Elixir/Plug.Router application
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Build Stage
# ------------------------------------------------------------------------------
FROM hexpm/elixir:1.15.7-erlang-26.2.1-alpine-3.18.4 AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    openssl-dev

# Set build environment
ENV MIX_ENV=prod \
    LANG=C.UTF-8

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy dependency files first for better caching
COPY mix.exs mix.lock* ./

# Fetch and compile dependencies
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy configuration
COPY config config

# Copy application code
COPY lib lib

# Compile application
RUN mix compile

# Create release
RUN mix release event_broadcast_service

# ------------------------------------------------------------------------------
# Stage 2: Runtime Stage
# ------------------------------------------------------------------------------
FROM alpine:3.18

# Install runtime dependencies
RUN apk add --no-cache \
    libstdc++ \
    openssl \
    ncurses-libs \
    libgcc \
    curl \
    && rm -rf /var/cache/apk/*

# Create non-root user for security
RUN addgroup -g 1000 elixir && \
    adduser -u 1000 -G elixir -s /bin/sh -D elixir

WORKDIR /app

# Copy release from builder
COPY --from=builder --chown=elixir:elixir /app/_build/prod/rel/event_broadcast_service ./

# Switch to non-root user
USER elixir

# Set environment variables
ENV HOME=/app \
    PORT=4007 \
    MIX_ENV=prod \
    RELEASE_DISTRIBUTION=none \
    ERL_FLAGS="+fnu"

# Expose HTTP port and EPMD port for distributed Erlang
EXPOSE 4007 4369

# Health check - verify service is responding
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:4007/health || exit 1

# Start the release
CMD ["bin/event_broadcast_service", "start"]
