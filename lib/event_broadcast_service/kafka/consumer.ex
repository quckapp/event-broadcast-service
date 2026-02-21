defmodule EventBroadcastService.Kafka.Consumer do
  @moduledoc "Kafka consumer for incoming events from other services"
  @behaviour :brod_group_subscriber
  require Logger

  @topic "events.incoming"

  def start_link(_opts) do
    kafka_hosts = get_kafka_hosts()
    group_id = "event-broadcast-service"

    Logger.info("Kafka Consumer starting for topic: #{@topic}")

    group_config = [
      offset_commit_policy: :commit_to_kafka_v2,
      offset_commit_interval_seconds: 5
    ]

    case :brod.start_client(kafka_hosts, :event_broadcast_client, _client_config = []) do
      :ok -> :ok
      {:error, {:already_started, _}} -> :ok
      {:error, reason} ->
        Logger.warning("Kafka client failed to start: #{inspect(reason)}")
        :ignore
    end
    |> case do
      :ok ->
        :brod.start_link_group_subscriber(
          :event_broadcast_client,
          group_id,
          [@topic],
          group_config,
          _consumer_config = [begin_offset: :latest],
          __MODULE__,
          _cb_init_arg = []
        )
      :ignore -> :ignore
    end
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end

  @impl :brod_group_subscriber
  def init(_group_id, _cb_init_arg) do
    Logger.info("Kafka consumer started successfully")
    {:ok, %{}}
  end

  @impl :brod_group_subscriber
  def handle_message(_topic, _partition, message, state) do
    try do
      value = :brod.message_value(message)
      event = Jason.decode!(value)
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
