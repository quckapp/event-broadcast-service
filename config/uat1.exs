# =============================================================================
# UAT1 Environment Configuration
# =============================================================================
# Use this profile for UAT1 environment
# Run with: MIX_ENV=uat1 mix run --no-halt
# =============================================================================

import Config

config :event_broadcast_service,
  port: String.to_integer(System.get_env("PORT") || "4006")

# MongoDB - UAT1
config :event_broadcast_service, :mongodb,
  url: System.get_env("MONGODB_URI"),
  pool_size: String.to_integer(System.get_env("MONGODB_POOL_SIZE") || "15")

# Redis - UAT1 (for pub/sub)
config :event_broadcast_service, :redis,
  host: System.get_env("REDIS_HOST"),
  port: String.to_integer(System.get_env("REDIS_PORT") || "6379"),
  password: System.get_env("REDIS_PASSWORD"),
  database: String.to_integer(System.get_env("REDIS_DATABASE") || "5")

# Kafka - UAT1 (for event distribution)
config :event_broadcast_service, :kafka,
  brokers: [System.get_env("KAFKA_BROKER") || "localhost:9092"],
  consumer_group: "event-broadcast-service-uat1",
  topics: %{
    events: System.get_env("KAFKA_EVENTS_TOPIC") || "quckapp-events-uat1",
    broadcasts: System.get_env("KAFKA_BROADCASTS_TOPIC") || "quckapp-broadcasts-uat1"
  }

# Services
config :event_broadcast_service, :services,
  auth_service_url: System.get_env("AUTH_SERVICE_URL"),
  user_service_url: System.get_env("USER_SERVICE_URL")

# Logging
config :logger, level: :info
