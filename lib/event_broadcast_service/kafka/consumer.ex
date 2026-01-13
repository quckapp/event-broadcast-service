defmodule EventBroadcastService.Kafka.Consumer do
  @moduledoc """
  Kafka consumer for incoming events from other services
  """
  use GenServer
  require Logger

  @topic "events.incoming"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    # In production, connect to Kafka
    kafka_hosts = get_kafka_hosts()
    group_id = "event-broadcast-service"

    Logger.info("Kafka Consumer starting for topic: #{@topic}")

    # Start consuming in a separate process
    spawn_link(fn -> start_consumer(kafka_hosts, group_id) end)

    {:ok, %{}}
  end

  defp start_consumer(hosts, group_id) do
    case :brod.start_link_group_subscriber(
           :event_broadcast_client,
           group_id,
           [@topic],
           _group_config = [offset_commit_policy: :commit_to_kafka_v2],
           _consumer_config = [begin_offset: :latest],
           __MODULE__,
           []
         ) do
      {:ok, _pid} ->
        Logger.info("Kafka consumer started successfully")

      {:error, reason} ->
        Logger.warning("Failed to start Kafka consumer: #{inspect(reason)}")
    end
  end

  # Callback for brod group subscriber
  def handle_message(_topic, _partition, message, state) do
    try do
      event = message |> elem(4) |> Jason.decode!()
      process_event(event)
      {:ok, :ack, state}
    rescue
      e ->
        Logger.error("Error processing Kafka message: #{inspect(e)}")
        {:ok, :ack, state}
    end
  end

  defp process_event(event) do
    case event["action"] do
      "broadcast" ->
        EventBroadcastService.Broadcaster.broadcast(event["payload"])

      "broadcast_targeted" ->
        EventBroadcastService.Broadcaster.broadcast_targeted(
          event["payload"],
          event["targets"]
        )

      action ->
        Logger.warning("Unknown event action: #{action}")
    end
  end

  defp get_kafka_hosts do
    host = System.get_env("KAFKA_HOST", "localhost")
    port = String.to_integer(System.get_env("KAFKA_PORT", "9092"))
    [{String.to_charlist(host), port}]
  end
end
