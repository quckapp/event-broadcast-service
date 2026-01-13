defmodule EventBroadcastService.Broadcaster do
  @moduledoc """
  Core event broadcasting logic
  """
  use GenServer
  require Logger

  @collection "event_history"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def broadcast(event) do
    GenServer.call(__MODULE__, {:broadcast, event})
  end

  def broadcast_targeted(event, targets) do
    GenServer.call(__MODULE__, {:broadcast_targeted, event, targets})
  end

  def get_event_history(channel_id, limit) do
    Mongo.find(:mongo, @collection, %{"channel_id" => channel_id}, [
      sort: %{"timestamp" => -1},
      limit: limit
    ])
    |> Enum.to_list()
  end

  def get_stats do
    %{
      total_events_24h: count_recent_events(24),
      events_per_minute: calculate_events_per_minute(),
      active_channels: count_active_channels()
    }
  end

  # GenServer callbacks

  @impl true
  def init(_) do
    {:ok, %{events_count: 0, last_minute_events: []}}
  end

  @impl true
  def handle_call({:broadcast, event}, _from, state) do
    enriched_event = enrich_event(event)

    # Store in MongoDB for history
    store_event(enriched_event)

    # Publish to Redis for real-time subscribers
    publish_to_redis(enriched_event)

    # Publish to Kafka for other services
    publish_to_kafka(enriched_event)

    # Broadcast via Phoenix PubSub
    Phoenix.PubSub.broadcast(
      EventBroadcastService.PubSub,
      "events:#{enriched_event["channel_id"]}",
      {:event, enriched_event}
    )

    Logger.debug("Broadcast event: #{enriched_event["type"]}")

    new_state = %{state |
      events_count: state.events_count + 1,
      last_minute_events: [DateTime.utc_now() | state.last_minute_events] |> Enum.take(1000)
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:broadcast_targeted, event, targets}, _from, state) do
    enriched_event = enrich_event(event)

    Enum.each(targets, fn target ->
      case target["type"] do
        "user" ->
          Phoenix.PubSub.broadcast(
            EventBroadcastService.PubSub,
            "user:#{target["id"]}",
            {:event, enriched_event}
          )
        "channel" ->
          Phoenix.PubSub.broadcast(
            EventBroadcastService.PubSub,
            "events:#{target["id"]}",
            {:event, enriched_event}
          )
        "workspace" ->
          Phoenix.PubSub.broadcast(
            EventBroadcastService.PubSub,
            "workspace:#{target["id"]}",
            {:event, enriched_event}
          )
        _ ->
          Logger.warning("Unknown target type: #{target["type"]}")
      end
    end)

    {:reply, :ok, state}
  end

  # Private functions

  defp enrich_event(event) do
    event
    |> Map.put("id", generate_id())
    |> Map.put("timestamp", DateTime.utc_now() |> DateTime.to_iso8601())
    |> Map.put_new("version", 1)
  end

  defp store_event(event) do
    Mongo.insert_one(:mongo, @collection, event)
  end

  defp publish_to_redis(event) do
    channel = "events:#{event["channel_id"]}"
    Redix.command(:redix, ["PUBLISH", channel, Jason.encode!(event)])
  end

  defp publish_to_kafka(event) do
    EventBroadcastService.Kafka.Producer.publish("events.broadcast", event)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(12) |> Base.encode16(case: :lower)
  end

  defp count_recent_events(hours) do
    since = DateTime.utc_now() |> DateTime.add(-hours * 3600, :second)
    Mongo.count_documents(:mongo, @collection, %{
      "timestamp" => %{"$gte" => DateTime.to_iso8601(since)}
    })
    |> case do
      {:ok, count} -> count
      _ -> 0
    end
  end

  defp calculate_events_per_minute do
    # Simple calculation based on recent state
    0
  end

  defp count_active_channels do
    Mongo.distinct(:mongo, @collection, "channel_id", %{
      "timestamp" => %{"$gte" => DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.to_iso8601()}
    })
    |> case do
      {:ok, channels} -> length(channels)
      _ -> 0
    end
  end
end
