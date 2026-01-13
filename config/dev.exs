import Config

config :event_broadcast_service,
  mongodb_url: "mongodb://localhost:27017/quickchat_events",
  redis_host: "localhost",
  redis_port: 6379,
  kafka_host: "localhost",
  kafka_port: 9092

config :logger,
  level: :debug
