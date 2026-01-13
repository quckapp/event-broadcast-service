defmodule EventBroadcastService.Router do
  @moduledoc """
  HTTP Router for Event Broadcast Service
  """
  use Plug.Router

  plug Plug.Logger
  plug :match
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :dispatch

  # Health endpoints
  get "/health" do
    send_resp(conn, 200, Jason.encode!(%{status: "healthy", service: "event-broadcast-service"}))
  end

  get "/health/ready" do
    checks = %{
      mongo: check_mongo(),
      redis: check_redis()
    }
    status = if Enum.all?(Map.values(checks), &(&1 == "ok")), do: 200, else: 503
    send_resp(conn, status, Jason.encode!(%{ready: status == 200, checks: checks}))
  end

  get "/health/live" do
    send_resp(conn, 200, Jason.encode!(%{live: true}))
  end

  # Broadcast event
  post "/api/v1/broadcast" do
    event = conn.body_params
    case EventBroadcastService.Broadcaster.broadcast(event) do
      :ok -> send_resp(conn, 200, Jason.encode!(%{success: true}))
      {:error, reason} -> send_resp(conn, 400, Jason.encode!(%{success: false, error: reason}))
    end
  end

  # Broadcast to specific targets
  post "/api/v1/broadcast/targeted" do
    %{"event" => event, "targets" => targets} = conn.body_params
    case EventBroadcastService.Broadcaster.broadcast_targeted(event, targets) do
      :ok -> send_resp(conn, 200, Jason.encode!(%{success: true}))
      {:error, reason} -> send_resp(conn, 400, Jason.encode!(%{success: false, error: reason}))
    end
  end

  # Get event history
  get "/api/v1/events/:channel_id" do
    limit = conn.params["limit"] || "50"
    events = EventBroadcastService.Broadcaster.get_event_history(channel_id, String.to_integer(limit))
    send_resp(conn, 200, Jason.encode!(%{success: true, data: events}))
  end

  # Subscribe endpoint info
  get "/api/v1/subscribe/info" do
    send_resp(conn, 200, Jason.encode!(%{
      websocket_url: "/ws",
      supported_events: [
        "message.created",
        "message.updated",
        "message.deleted",
        "user.presence",
        "typing.start",
        "typing.stop",
        "channel.updated",
        "reaction.added",
        "reaction.removed"
      ]
    }))
  end

  # Stats endpoint
  get "/api/v1/stats" do
    stats = EventBroadcastService.Broadcaster.get_stats()
    send_resp(conn, 200, Jason.encode!(%{success: true, data: stats}))
  end

  match _ do
    send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
  end

  defp check_mongo do
    case Mongo.command(:mongo, %{ping: 1}) do
      {:ok, _} -> "ok"
      _ -> "error"
    end
  end

  defp check_redis do
    case Redix.command(:redix, ["PING"]) do
      {:ok, "PONG"} -> "ok"
      _ -> "error"
    end
  end
end
