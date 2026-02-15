import Config

# ==============================================================================
# Runtime Configuration for Event Broadcast Service
# ==============================================================================
# This file is evaluated at runtime, allowing configuration from environment
# variables. This is essential for Docker deployments.

# Helper function to parse boolean environment variables
parse_boolean = fn
  "true" -> true
  "1" -> true
  "yes" -> true
  _ -> false
end

# Helper function to parse integer with default
parse_integer = fn env_var, default ->
  case System.get_env(env_var) do
    nil -> default
    value -> String.to_integer(value)
  end
end

# ==============================================================================
# Production Environment Configuration
# ==============================================================================
if config_env() in [:prod, :production, :staging, :live, :qa, :uat1, :uat2, :uat3] do
  # --------------------------------------------------------------------------
  # Application Port
  # --------------------------------------------------------------------------
  port = parse_integer.("PORT", 4007)

  config :event_broadcast_service,
    port: port

  # --------------------------------------------------------------------------
  # MongoDB Configuration
  # --------------------------------------------------------------------------
  mongodb_url = System.get_env("MONGODB_URL") ||
                System.get_env("MONGODB_URI") ||
                raise """
                Environment variable MONGODB_URL is missing.
                Example: mongodb://localhost:27017/quckapp_events
                """

  mongodb_pool_size = parse_integer.("MONGODB_POOL_SIZE", 10)

  config :event_broadcast_service, :mongodb,
    url: mongodb_url,
    pool_size: mongodb_pool_size

  # --------------------------------------------------------------------------
  # Redis Configuration
  # --------------------------------------------------------------------------
  redis_host = System.get_env("REDIS_HOST") ||
               raise """
               Environment variable REDIS_HOST is missing.
               Example: localhost or redis
               """

  redis_port = parse_integer.("REDIS_PORT", 6379)
  redis_database = parse_integer.("REDIS_DATABASE", 5)
  redis_password = System.get_env("REDIS_PASSWORD")

  # Build Redis URL if not provided directly
  redis_url = System.get_env("REDIS_URL") ||
              if redis_password do
                "redis://:#{redis_password}@#{redis_host}:#{redis_port}/#{redis_database}"
              else
                "redis://#{redis_host}:#{redis_port}/#{redis_database}"
              end

  config :event_broadcast_service, :redis,
    url: redis_url,
    host: redis_host,
    port: redis_port,
    database: redis_database,
    password: redis_password

  # --------------------------------------------------------------------------
  # Kafka Configuration
  # --------------------------------------------------------------------------
  kafka_enabled = System.get_env("KAFKA_ENABLED", "false") == "true"
  kafka_brokers_string = System.get_env("KAFKA_BROKERS") || System.get_env("KAFKA_BROKER") || "localhost:9092"

  # Parse comma-separated broker list into keyword list format for brod
  kafka_endpoints =
    kafka_brokers_string
    |> String.split(",")
    |> Enum.map(fn broker ->
      case String.split(String.trim(broker), ":") do
        [host, port] -> {String.to_charlist(host), String.to_integer(port)}
        [host] -> {String.to_charlist(host), 9092}
      end
    end)

  kafka_consumer_group = System.get_env("KAFKA_CONSUMER_GROUP", "event-broadcast-service-group")

  config :event_broadcast_service, :kafka,
    enabled: kafka_enabled,
    brokers: kafka_brokers_string,
    endpoints: kafka_endpoints,
    consumer_group: kafka_consumer_group,
    topics: %{
      events: System.get_env("KAFKA_EVENTS_TOPIC", "quckapp-events"),
      broadcasts: System.get_env("KAFKA_BROADCASTS_TOPIC", "quckapp-broadcasts")
    }

  # --------------------------------------------------------------------------
  # Service URLs (for inter-service communication)
  # --------------------------------------------------------------------------
  config :event_broadcast_service, :services,
    auth_service_url: System.get_env("AUTH_SERVICE_URL", "http://auth-service:4001"),
    user_service_url: System.get_env("USER_SERVICE_URL", "http://user-service:4002"),
    message_service_url: System.get_env("MESSAGE_SERVICE_URL", "http://message-service:4003"),
    channel_service_url: System.get_env("CHANNEL_SERVICE_URL", "http://channel-service:4004")

  # --------------------------------------------------------------------------
  # Logging Configuration
  # --------------------------------------------------------------------------
  log_level =
    case System.get_env("LOG_LEVEL", "info") do
      "debug" -> :debug
      "info" -> :info
      "warn" -> :warning
      "warning" -> :warning
      "error" -> :error
      _ -> :info
    end

  config :logger,
    level: log_level

  config :logger, :console,
    format: "$time $metadata[$level] $message\n",
    metadata: [:request_id, :event_id, :channel_id, :user_id]

  # --------------------------------------------------------------------------
  # Telemetry & Metrics
  # --------------------------------------------------------------------------
  config :event_broadcast_service, :telemetry,
    enabled: parse_boolean.(System.get_env("TELEMETRY_ENABLED", "true"))

  # --------------------------------------------------------------------------
  # Security Configuration
  # --------------------------------------------------------------------------
  secret_key_base = System.get_env("SECRET_KEY_BASE")

  if secret_key_base do
    config :event_broadcast_service,
      secret_key_base: secret_key_base
  end

  # --------------------------------------------------------------------------
  # Erlang/OTP Distribution (for clustering)
  # --------------------------------------------------------------------------
  release_distribution = System.get_env("RELEASE_DISTRIBUTION", "none")
  release_node = System.get_env("RELEASE_NODE")
  release_cookie = System.get_env("RELEASE_COOKIE")

  if release_distribution != "none" and release_node do
    config :event_broadcast_service,
      node_name: String.to_atom(release_node),
      cookie: if(release_cookie, do: String.to_atom(release_cookie), else: nil)
  end
end

# ==============================================================================
# Development/Local Environment Configuration
# ==============================================================================
if config_env() in [:dev, :local] do
  config :event_broadcast_service,
    port: parse_integer.("PORT", 4007)

  config :event_broadcast_service, :mongodb,
    url: System.get_env("MONGODB_URL", "mongodb://localhost:27017/quckapp_events"),
    pool_size: 5

  config :event_broadcast_service, :redis,
    host: System.get_env("REDIS_HOST", "localhost"),
    port: parse_integer.("REDIS_PORT", 6379),
    database: parse_integer.("REDIS_DATABASE", 5)

  config :event_broadcast_service, :kafka,
    enabled: System.get_env("KAFKA_ENABLED", "false") == "true",
    brokers: System.get_env("KAFKA_BROKERS", "localhost:9092"),
    endpoints: [{~c"localhost", 9092}],
    consumer_group: "event-broadcast-service-group-dev",
    topics: %{
      events: "quckapp-events-dev",
      broadcasts: "quckapp-broadcasts-dev"
    }

  config :event_broadcast_service, :services,
    auth_service_url: System.get_env("AUTH_SERVICE_URL", "http://localhost:4001"),
    user_service_url: System.get_env("USER_SERVICE_URL", "http://localhost:4002")

  config :logger,
    level: :debug
end

# ==============================================================================
# Test Environment Configuration
# ==============================================================================
if config_env() == :test do
  config :event_broadcast_service,
    port: 4017

  config :event_broadcast_service, :mongodb,
    url: "mongodb://localhost:27017/quckapp_events_test",
    pool_size: 2

  config :event_broadcast_service, :redis,
    host: "localhost",
    port: 6379,
    database: 15

  config :event_broadcast_service, :kafka,
    enabled: false,
    brokers: "localhost:9092",
    endpoints: [{~c"localhost", 9092}],
    consumer_group: "event-broadcast-service-group-test",
    topics: %{
      events: "quckapp-events-test",
      broadcasts: "quckapp-broadcasts-test"
    }

  config :logger,
    level: :warning
end
