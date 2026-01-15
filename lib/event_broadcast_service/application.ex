defmodule EventBroadcastService.Application do
  @moduledoc """
  EventBroadcastService - Distributes events across services and clients
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # MongoDB connection
      {Mongo, [
        name: :mongo,
        url: System.get_env("MONGODB_URL", "mongodb://localhost:27017/quckapp_events"),
        pool_size: 10
      ]},
      # Redis connection for pub/sub
      {Redix, [
        name: :redix,
        host: System.get_env("REDIS_HOST", "localhost"),
        port: String.to_integer(System.get_env("REDIS_PORT", "6379"))
      ]},
      # PubSub for internal broadcasting
      {Phoenix.PubSub, name: EventBroadcastService.PubSub},
      # Event Registry
      {Registry, keys: :duplicate, name: EventBroadcastService.SubscriberRegistry},
      # Kafka Consumer
      EventBroadcastService.Kafka.Consumer,
      # Kafka Producer
      EventBroadcastService.Kafka.Producer,
      # Event Broadcaster
      EventBroadcastService.Broadcaster,
      # HTTP Endpoint
      {Plug.Cowboy, scheme: :http, plug: EventBroadcastService.Router, options: [port: port()]}
    ]

    opts = [strategy: :one_for_one, name: EventBroadcastService.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp port do
    String.to_integer(System.get_env("PORT", "4006"))
  end
end
