import Config

if config_env() == :prod do
  config :event_broadcast_service,
    mongodb_url: System.get_env("MONGODB_URL") || raise("MONGODB_URL not set"),
    redis_host: System.get_env("REDIS_HOST") || raise("REDIS_HOST not set"),
    redis_port: String.to_integer(System.get_env("REDIS_PORT") || "6379"),
    kafka_host: System.get_env("KAFKA_HOST") || raise("KAFKA_HOST not set"),
    kafka_port: String.to_integer(System.get_env("KAFKA_PORT") || "9092")
end
