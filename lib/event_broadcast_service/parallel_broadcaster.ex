defmodule EventBroadcastService.ParallelBroadcaster do
  @moduledoc """
  Flow-based parallel event broadcaster.

  Uses Elixir Flow library for parallel broadcasting to multiple destinations:
  - Redis pub/sub
  - MongoDB event history
  - Kafka event stream
  - Phoenix PubSub

  ## Usage:

      # Broadcast event to all destinations in parallel
      ParallelBroadcaster.broadcast_all(event)

      # Broadcast to specific targets
      ParallelBroadcaster.broadcast_targeted(event, targets)

  ## Configuration:

  Configure in config.exs:

      config :event_broadcast_service, :parallel_broadcaster,
        max_demand: 100,
        stages: System.schedulers_online(),
        destinations: [:redis, :mongodb, :kafka, :pubsub]
  """

  require Logger

  alias EventBroadcastService.CircuitBreaker

  @destinations [:redis, :mongodb, :kafka, :pubsub]

  @doc """
  Broadcast an event to all configured destinations in parallel.

  Returns a map of destination => result.
  """
  def broadcast_all(event) do
    enriched = enrich_event(event)

    results =
      destinations()
      |> Flow.from_enumerable(stages: 4)
      |> Flow.map(fn destination ->
        result = broadcast_to_destination(destination, enriched)
        {destination, result}
      end)
      |> Enum.to_list()
      |> Map.new()

    emit_telemetry(enriched, results)

    {:ok, results}
  end

  @doc """
  Broadcast an event to multiple targets in parallel.

  Targets format: [%{"type" => "user" | "channel" | "workspace", "id" => "..."}, ...]
  """
  def broadcast_targeted(event, targets) when is_list(targets) do
    enriched = enrich_event(event)

    # Store event first
    Task.start(fn -> store_event(enriched) end)

    results =
      targets
      |> Flow.from_enumerable(max_demand: max_demand(), stages: stages())
      |> Flow.map(fn target ->
        broadcast_to_target(enriched, target)
      end)
      |> Enum.to_list()

    delivered = Enum.count(results, &(&1 == :ok))
    failed = Enum.count(results, &(&1 == :error))

    {:ok, %{delivered: delivered, failed: failed, total: length(targets)}}
  end

  @doc """
  Broadcast multiple events to their respective channels in parallel.
  """
  def broadcast_batch(events) when is_list(events) do
    case length(events) do
      0 ->
        {:ok, %{processed: 0}}

      count when count <= 5 ->
        # Small batch, process sequentially
        Enum.each(events, &broadcast_all/1)
        {:ok, %{processed: count}}

      _ ->
        # Large batch, process in parallel
        results =
          events
          |> Flow.from_enumerable(max_demand: max_demand(), stages: stages())
          |> Flow.map(fn event ->
            case broadcast_all(event) do
              {:ok, _} -> :ok
              {:error, _} -> :error
            end
          end)
          |> Enum.to_list()

        processed = Enum.count(results, &(&1 == :ok))
        {:ok, %{processed: processed, failed: length(results) - processed}}
    end
  end

  @doc """
  Fan out an event to multiple user channels.
  """
  def fan_out_to_users(event, user_ids) when is_list(user_ids) do
    enriched = enrich_event(event)

    results =
      user_ids
      |> Flow.from_enumerable(max_demand: max_demand(), stages: stages())
      |> Flow.map(fn user_id ->
        Phoenix.PubSub.broadcast(
          EventBroadcastService.PubSub,
          "user:#{user_id}",
          {:event, enriched}
        )
      end)
      |> Enum.to_list()

    {:ok, %{delivered: length(results)}}
  end

  # Private functions

  defp broadcast_to_destination(:redis, event) do
    CircuitBreaker.call(:redis, fn ->
      channel = "events:#{event["channel_id"]}"
      Redix.command(:redix, ["PUBLISH", channel, Jason.encode!(event)])
    end, default: {:error, :circuit_open})
  end

  defp broadcast_to_destination(:mongodb, event) do
    CircuitBreaker.call(:mongodb, fn ->
      Mongo.insert_one(:mongo, "event_history", event)
    end, default: {:error, :circuit_open})
  end

  defp broadcast_to_destination(:kafka, event) do
    CircuitBreaker.call(:kafka, fn ->
      EventBroadcastService.Kafka.Producer.publish("events.broadcast", event)
    end, default: {:error, :circuit_open})
  end

  defp broadcast_to_destination(:pubsub, event) do
    Phoenix.PubSub.broadcast(
      EventBroadcastService.PubSub,
      "events:#{event["channel_id"]}",
      {:event, event}
    )
  end

  defp broadcast_to_destination(unknown, _event) do
    Logger.warning("[ParallelBroadcaster] Unknown destination: #{inspect(unknown)}")
    {:error, :unknown_destination}
  end

  defp broadcast_to_target(event, target) do
    try do
      case target["type"] || target[:type] do
        "user" ->
          Phoenix.PubSub.broadcast(
            EventBroadcastService.PubSub,
            "user:#{target["id"] || target[:id]}",
            {:event, event}
          )
          :ok

        "channel" ->
          Phoenix.PubSub.broadcast(
            EventBroadcastService.PubSub,
            "events:#{target["id"] || target[:id]}",
            {:event, event}
          )
          :ok

        "workspace" ->
          Phoenix.PubSub.broadcast(
            EventBroadcastService.PubSub,
            "workspace:#{target["id"] || target[:id]}",
            {:event, event}
          )
          :ok

        unknown ->
          Logger.warning("[ParallelBroadcaster] Unknown target type: #{inspect(unknown)}")
          :error
      end
    rescue
      e ->
        Logger.error("[ParallelBroadcaster] Failed to broadcast to target: #{inspect(e)}")
        :error
    end
  end

  defp enrich_event(event) do
    event
    |> Map.put("id", generate_id())
    |> Map.put("timestamp", DateTime.utc_now() |> DateTime.to_iso8601())
    |> Map.put_new("version", 1)
  end

  defp store_event(event) do
    CircuitBreaker.call(:mongodb, fn ->
      Mongo.insert_one(:mongo, "event_history", event)
    end, default: {:error, :circuit_open})
  end

  defp generate_id do
    :crypto.strong_rand_bytes(12) |> Base.encode16(case: :lower)
  end

  defp emit_telemetry(event, results) do
    success_count = Enum.count(results, fn {_, result} ->
      case result do
        {:ok, _} -> true
        :ok -> true
        _ -> false
      end
    end)

    :telemetry.execute(
      [:event_broadcast_service, :broadcast],
      %{count: 1, destinations: length(destinations()), success: success_count},
      %{event_type: event["type"]}
    )
  end

  defp destinations do
    config()[:destinations] || @destinations
  end

  defp max_demand do
    config()[:max_demand] || 100
  end

  defp stages do
    config()[:stages] || System.schedulers_online()
  end

  defp config do
    Application.get_env(:event_broadcast_service, :parallel_broadcaster, [])
  end
end
