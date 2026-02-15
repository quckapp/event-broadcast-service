# =============================================================================
# DEV Environment Configuration
# =============================================================================
# Use this profile for development
# Run with: MIX_ENV=dev mix run --no-halt
# =============================================================================

import Config

config :event_broadcast_service,
  port: 4006

# MongoDB - Dev
config :event_broadcast_service, :mongodb,
  url: "mongodb://localhost:27017/quckapp_events_dev",
  pool_size: 5

# Redis - Dev (for pub/sub)
config :event_broadcast_service, :redis,
  host: "localhost",
  port: 6379,
  password: nil,
  database: 5

# Kafka - Dev (for event distribution) - disabled by default
config :event_broadcast_service, :kafka,
  enabled: false,
  brokers: [{~c"localhost", 9092}],
  endpoints: [{~c"localhost", 9092}],
  consumer_group: "event-broadcast-service-dev",
  topics: %{
    events: "quckapp-events-dev",
    broadcasts: "quckapp-broadcasts-dev"
  }

# Logging - Debug for dev
config :logger, level: :debug
