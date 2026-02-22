import Config

config :event_broadcast_service,
  port: 4007

# MongoDB default configuration
config :event_broadcast_service, :mongodb,
  url: System.get_env("MONGODB_URI") || "mongodb://localhost:27017/quckapp_events",
  pool_size: 10

# Redis configuration (for pub/sub)
config :event_broadcast_service, :redis,
  host: System.get_env("REDIS_HOST") || "localhost",
  port: String.to_integer(System.get_env("REDIS_PORT") || "6379"),
  database: 5

# Kafka configuration (for event distribution)
config :event_broadcast_service, :kafka,
  enabled: false,
  brokers: [{~c"localhost", 9092}],
  consumer_group: "event-broadcast-service-group",
  topics: %{
    events: "quckapp-events",
    broadcasts: "quckapp-broadcasts"
  }

config :logger,
  level: :info

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :event_id]

# Import environment-specific config
# Environments: dev, test, local, qa, uat1, uat2, uat3, staging, production, live, prod
if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
