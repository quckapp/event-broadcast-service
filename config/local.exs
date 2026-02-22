# =============================================================================
# LOCAL (Mock) Environment Configuration
# =============================================================================
# Use this profile for local development with Docker containers
# Run with: MIX_ENV=local mix run --no-halt
# =============================================================================

import Config

config :event_broadcast_service,
  port: 4006

# MongoDB - Local Docker
config :event_broadcast_service, :mongodb,
  url: "mongodb://localhost:27017/quckapp_events_local",
  pool_size: 5

# Redis - Local Docker (for pub/sub)
config :event_broadcast_service, :redis,
  host: "localhost",
  port: 6379,
  password: nil,
  database: 5

# Kafka - Local Docker (for event distribution)
config :event_broadcast_service, :kafka,
  brokers: [{"localhost", 9092}],
  consumer_group: "event-broadcast-service-local",
  topics: %{
    events: "quckapp-events-local",
    broadcasts: "quckapp-broadcasts-local"
  }

# Services
config :event_broadcast_service, :services,
  auth_service_url: "http://localhost:8081",
  user_service_url: "http://localhost:8082"

# Logging - Verbose for local
config :logger, :console,
  format: "[$level] $message\n",
  level: :debug
