defmodule EventBroadcastService.Kafka.Consumer do
  @moduledoc "Kafka consumer for incoming events from other services"
  @behaviour :brod_group_subscriber
  require Logger

  # Valid event types - prevents atom table exhaustion
  @valid_event_types ~w(broadcast broadcast_targeted subscribe unsubscribe)
  @valid_channels ~w(all users groups conversations system)

  def start_link(_opts) do
    kafka_hosts = get_kafka_hosts()
    group_id = "event-broadcast-service"

  @impl true
  def handle_info(:connect, state) do
    case connect_to_kafka(state) do
      {:ok, new_state} ->
        Logger.info("[EventKafkaConsumer] Successfully connected to Kafka")
        {:noreply, %{new_state | circuit_state: :closed, failure_count: 0}}

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

  # ============================================================================
  # Private Functions - Circuit Breaker
  # ============================================================================

  defp handle_connection_failure(state, reason) do
    new_failure_count = state.failure_count + 1
    Logger.warning("[EventKafkaConsumer] Connection failed (#{new_failure_count}/#{@max_failures}): #{inspect(reason)}")

    new_state = %{state |
      failure_count: new_failure_count,
      last_failure_at: System.system_time(:millisecond),
      consumer_pid: nil
    }

    if new_failure_count >= @max_failures do
      Logger.error("[EventKafkaConsumer] Circuit breaker OPEN - max failures reached")
      schedule_retry()
      %{new_state | circuit_state: :open}
    else
      schedule_retry()
      new_state
    end
  end

  defp should_attempt_reset?(state) do
    case state.last_failure_at do
      nil -> true
      last_failure ->
        elapsed = System.system_time(:millisecond) - last_failure
        elapsed >= @reset_timeout_ms
    end
  end

  defp schedule_retry, do: Process.send_after(self(), :retry_connect, @retry_delay_ms)
  defp schedule_cleanup, do: Process.send_after(self(), :cleanup_dedup, @dedup_window_ms)
  defp schedule_stats_update, do: Process.send_after(self(), :update_stats, 10_000)

  # ============================================================================
  # Private Functions - Message Processing
  # ============================================================================

  defp safe_process_message(topic, _partition, message) do
    with {:ok, payload} <- extract_payload(message),
         {:ok, event} <- Jason.decode(payload),
         :ok <- process_event(topic, event) do
      :telemetry.execute(
        [:event_broadcast_service, :kafka, :message_processed],
        %{count: 1},
        %{topic: topic}
      )
      :ok
    else
      {:error, :invalid_json} ->
        Logger.warning("[EventKafkaConsumer] Invalid JSON in message")
        {:error, :invalid_json}

      {:error, :unknown_event} ->
        :ok

      {:error, reason} ->
        Logger.error("[EventKafkaConsumer] Error processing message: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp extract_payload(message) when is_map(message), do: {:ok, message.value}
  defp extract_payload(message) when is_tuple(message), do: {:ok, elem(message, 4)}
  defp extract_payload(_), do: {:error, :invalid_message_format}

  defp extract_message_id(message) do
    case message do
      %{key: key} when is_binary(key) -> key
      %{offset: offset, partition: partition} -> "#{partition}-#{offset}"
      tuple when is_tuple(tuple) -> "#{elem(tuple, 1)}-#{elem(tuple, 2)}"
      _ -> :crypto.strong_rand_bytes(16) |> Base.encode16()
    end
  end

  # ============================================================================
  # Private Functions - Event Handlers (Strategy Pattern)
  # ============================================================================

  defp process_event(_topic, %{"action" => "broadcast", "payload" => payload}) do
    Task.start(fn ->
      broadcast_to_all(payload)
    end)
    :ok
  end

  defp process_event(_topic, %{"action" => "broadcast_targeted", "payload" => payload, "targets" => targets}) do
    Task.start(fn ->
      broadcast_to_targets(payload, targets)
    end)
    :ok
  end

  defp process_event(_topic, %{"action" => "broadcast_channel", "channel" => channel, "payload" => payload}) do
    with {:ok, _} <- validate_channel(channel) do
      Task.start(fn ->
        broadcast_to_channel(channel, payload)
      end)
      :ok
    end
  end

  defp process_event(_topic, %{"action" => "broadcast_user", "user_id" => user_id, "payload" => payload}) do
    Task.start(fn ->
      broadcast_to_user(user_id, payload)
    end)
    :ok
  end

  defp process_event(_topic, %{"action" => "broadcast_conversation", "conversation_id" => conversation_id, "payload" => payload}) do
    Task.start(fn ->
      broadcast_to_conversation(conversation_id, payload)
    end)
    :ok
  end

  defp process_event(_topic, %{"action" => "system_event", "event_type" => event_type} = event) do
    Task.start(fn ->
      broadcast_system_event(event_type, event["data"] || %{})
    end)
    :ok
  end

  defp process_event(_topic, %{"action" => action} = event) do
    Logger.debug("[EventKafkaConsumer] Unhandled action: #{action}, payload: #{inspect(event)}")
    {:error, :unknown_event}
  end

  defp process_event(_topic, _event) do
    {:error, :unknown_event}
  end

  # ============================================================================
  # Private Functions - Broadcasting (Fan-Out Pattern)
  # ============================================================================

  defp broadcast_to_all(payload) do
    Phoenix.PubSub.broadcast(
      EventBroadcastService.PubSub,
      "events:all",
      {:event, payload}
    )
  end

  defp broadcast_to_targets(payload, targets) when is_list(targets) do
    Enum.each(targets, fn target ->
      case target do
        %{"type" => "user", "id" => user_id} ->
          broadcast_to_user(user_id, payload)

        %{"type" => "conversation", "id" => conversation_id} ->
          broadcast_to_conversation(conversation_id, payload)

        %{"type" => "channel", "name" => channel} ->
          broadcast_to_channel(channel, payload)

        _ ->
          Logger.warning("[EventKafkaConsumer] Unknown target type: #{inspect(target)}")
      end
    end)
  end

  defp broadcast_to_targets(_payload, _targets), do: :ok

  defp broadcast_to_channel(channel, payload) do
    Phoenix.PubSub.broadcast(
      EventBroadcastService.PubSub,
      "channel:#{channel}",
      {:event, payload}
    )
  end

  defp broadcast_to_user(user_id, payload) do
    Phoenix.PubSub.broadcast(
      EventBroadcastService.PubSub,
      "user:#{user_id}",
      {:event, payload}
    )
  end

  defp broadcast_to_conversation(conversation_id, payload) do
    Phoenix.PubSub.broadcast(
      EventBroadcastService.PubSub,
      "conversation:#{conversation_id}",
      {:event, payload}
    )
  end

  defp broadcast_system_event(event_type, data) do
    Phoenix.PubSub.broadcast(
      EventBroadcastService.PubSub,
      "system:events",
      {:system_event, event_type, data}
    )
  end

  # ============================================================================
  # Private Functions - Validation
  # ============================================================================

  defp validate_channel(channel) when channel in @valid_channels do
    {:ok, channel}
  end

  defp validate_channel(_channel), do: {:error, :invalid_channel}

  # ============================================================================
  # Private Functions - Deduplication & Stats
  # ============================================================================

  defp is_duplicate?(message_id) do
    case :ets.lookup(:event_kafka_dedup, message_id) do
      [{^message_id, _timestamp}] -> true
      [] -> false
    end
  end

  defp mark_processed(message_id) do
    timestamp = System.system_time(:millisecond)
    :ets.insert(:event_kafka_dedup, {message_id, timestamp})
  end

  defp init_stats do
    :ets.insert(:event_kafka_stats, {:events_broadcasted, 0})
    :ets.insert(:event_kafka_stats, {:events_failed, 0})
  end

  defp get_stat(key) do
    case :ets.lookup(:event_kafka_stats, key) do
      [{^key, value}] -> value
      [] -> 0
    end
  end

  defp increment_stat(key) do
    :ets.update_counter(:event_kafka_stats, key, 1)
  rescue
    _ -> :ok
  end

  defp count_subscribers do
    # Approximate count based on ETS or registry
    # This is a simplified version
    0
  end
end
