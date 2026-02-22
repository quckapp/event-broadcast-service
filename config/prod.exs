# =============================================================================
# PROD Environment Configuration (Compile-time)
# =============================================================================
# This file contains compile-time configuration for production.
# Runtime configuration is handled in config/runtime.exs
# =============================================================================

import Config

# Use production logger level - runtime.exs can override this
config :logger, level: :info

# Compile-time settings for production
config :event_broadcast_service,
  env: :prod

# Note: All runtime configuration (MongoDB, Redis, Kafka, etc.)
# is handled in config/runtime.exs to allow Docker deployments
# without requiring environment variables at compile time.
