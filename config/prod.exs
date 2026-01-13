import Config

config :event_broadcast_service,
  mongodb_url: System.get_env("MONGODB_URL"),
  redis_host: System.get_env("REDIS_HOST"),
  redis_port: String.to_integer(System.get_env("REDIS_PORT") || "6379"),
  kafka_host: System.get_env("KAFKA_HOST"),
  kafka_port: String.to_integer(System.get_env("KAFKA_PORT") || "9092")

config :logger,
  level: :info
