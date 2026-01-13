defmodule EventBroadcastService.Kafka.Producer do
  @moduledoc """
  Kafka producer for publishing broadcast events
  """
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def publish(topic, event) do
    GenServer.cast(__MODULE__, {:publish, topic, event})
  end

  @impl true
  def init(_) do
    kafka_hosts = get_kafka_hosts()

    case :brod.start_client(kafka_hosts, :event_broadcast_client, []) do
      :ok ->
        Logger.info("Kafka producer connected")
        {:ok, %{client: :event_broadcast_client}}

      {:error, {:already_started, _}} ->
        {:ok, %{client: :event_broadcast_client}}

      {:error, reason} ->
        Logger.warning("Failed to connect Kafka producer: #{inspect(reason)}")
        {:ok, %{client: nil}}
    end
  end

  @impl true
  def handle_cast({:publish, topic, event}, %{client: nil} = state) do
    Logger.warning("Kafka client not connected, dropping event for topic: #{topic}")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:publish, topic, event}, %{client: client} = state) do
    message = Jason.encode!(event)
    partition_key = event["channel_id"] || event["id"] || ""

    case :brod.produce_sync(client, topic, :hash, partition_key, message) do
      :ok ->
        Logger.debug("Published event to Kafka topic: #{topic}")

      {:error, reason} ->
        Logger.error("Failed to publish to Kafka: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  defp get_kafka_hosts do
    host = System.get_env("KAFKA_HOST", "localhost")
    port = String.to_integer(System.get_env("KAFKA_PORT", "9092"))
    [{String.to_charlist(host), port}]
  end
end
