# =============================================================================
# LIVE Environment Configuration
# =============================================================================
# Use this profile for live environment (same as production with stricter settings)
# Run with: MIX_ENV=live mix run --no-halt
# =============================================================================

import Config

config :event_broadcast_service,
  port: String.to_integer(System.get_env("PORT") || "4006")

# MongoDB - Live (highest pool size)
config :event_broadcast_service, :mongodb,
  url: System.get_env("MONGODB_URI") || raise("MONGODB_URI missing"),
  pool_size: String.to_integer(System.get_env("MONGODB_POOL_SIZE") || "100"),
  timeout: 15_000,
  connect_timeout: 10_000

# Redis - Live (for pub/sub)
config :event_broadcast_service, :redis,
  host: System.get_env("REDIS_HOST") || raise("REDIS_HOST missing"),
  port: String.to_integer(System.get_env("REDIS_PORT") || "6379"),
  password: System.get_env("REDIS_PASSWORD"),
  database: String.to_integer(System.get_env("REDIS_DATABASE") || "5"),
  pool_size: 64,
  ssl: System.get_env("REDIS_SSL") == "true"

# Kafka - Live (for event distribution)
config :event_broadcast_service, :kafka,
  brokers: String.split(System.get_env("KAFKA_BROKERS") || "localhost:9092", ","),
  consumer_group: "event-broadcast-service-live",
  ssl: System.get_env("KAFKA_SSL") == "true",
  topics: %{
    events: System.get_env("KAFKA_EVENTS_TOPIC") || "quckapp-events-live",
    broadcasts: System.get_env("KAFKA_BROADCASTS_TOPIC") || "quckapp-broadcasts-live"
  }

# Services
config :event_broadcast_service, :services,
  auth_service_url: System.get_env("AUTH_SERVICE_URL") || raise("AUTH_SERVICE_URL missing"),
  user_service_url: System.get_env("USER_SERVICE_URL") || raise("USER_SERVICE_URL missing")

# Logging - Error level only for live
config :logger, level: :error
