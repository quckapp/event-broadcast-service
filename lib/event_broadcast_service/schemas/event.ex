defmodule EventBroadcastService.Schemas.Event do
  @moduledoc """
  Event-related schemas for API requests and responses
  """
  alias OpenApiSpex.Schema
  require OpenApiSpex

  defmodule EventMetadata do
    @moduledoc """
    Event metadata schema
    """
    OpenApiSpex.schema(%{
      title: "EventMetadata",
      description: "Additional metadata for the event",
      type: :object,
      properties: %{
        source: %Schema{type: :string, description: "Source of the event", example: "user-service"},
        correlation_id: %Schema{type: :string, description: "Correlation ID for tracing", example: "corr-123abc"},
        user_agent: %Schema{type: :string, description: "User agent string", example: "Mozilla/5.0"}
      },
      additionalProperties: true,
      example: %{
        source: "user-service",
        correlation_id: "corr-123abc"
      }
    })
  end

  defmodule BroadcastEventRequest do
    @moduledoc """
    Request schema for broadcasting an event
    """
    OpenApiSpex.schema(%{
      title: "BroadcastEventRequest",
      description: "Request body for broadcasting an event",
      type: :object,
      properties: %{
        type: %Schema{
          type: :string,
          description: "Event type",
          example: "message.created",
          enum: [
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
        },
        channel_id: %Schema{
          type: :string,
          description: "Target channel ID",
          example: "ch_123abc456def"
        },
        data: %Schema{
          type: :object,
          description: "Event payload data",
          additionalProperties: true,
          example: %{
            message_id: "msg_789",
            content: "Hello world",
            user_id: "usr_456"
          }
        },
        metadata: EventMetadata
      },
      required: [:type, :channel_id, :data],
      example: %{
        type: "message.created",
        channel_id: "ch_123abc456def",
        data: %{
          message_id: "msg_789",
          content: "Hello world",
          user_id: "usr_456"
        },
        metadata: %{
          source: "user-service",
          correlation_id: "corr-123abc"
        }
      }
    })
  end

  defmodule BroadcastTarget do
    @moduledoc """
    Target specification for targeted broadcasts
    """
    OpenApiSpex.schema(%{
      title: "BroadcastTarget",
      description: "Target specification for targeted broadcast",
      type: :object,
      properties: %{
        type: %Schema{
          type: :string,
          description: "Target type",
          enum: ["user", "channel", "workspace"],
          example: "user"
        },
        id: %Schema{
          type: :string,
          description: "Target identifier",
          example: "usr_123abc"
        }
      },
      required: [:type, :id],
      example: %{
        type: "user",
        id: "usr_123abc"
      }
    })
  end

  defmodule TargetedBroadcastRequest do
    @moduledoc """
    Request schema for targeted event broadcasting
    """
    OpenApiSpex.schema(%{
      title: "TargetedBroadcastRequest",
      description: "Request body for broadcasting an event to specific targets",
      type: :object,
      properties: %{
        event: BroadcastEventRequest,
        targets: %Schema{
          type: :array,
          description: "List of targets to receive the event",
          items: BroadcastTarget,
          minItems: 1
        }
      },
      required: [:event, :targets],
      example: %{
        event: %{
          type: "user.presence",
          channel_id: "ch_123abc456def",
          data: %{
            user_id: "usr_456",
            status: "online"
          }
        },
        targets: [
          %{type: "user", id: "usr_789"},
          %{type: "channel", id: "ch_abc123"}
        ]
      }
    })
  end

  defmodule EventResponse do
    @moduledoc """
    Event object response schema
    """
    OpenApiSpex.schema(%{
      title: "EventResponse",
      description: "Event object with all properties",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Unique event identifier", example: "evt_abc123def456"},
        type: %Schema{type: :string, description: "Event type", example: "message.created"},
        channel_id: %Schema{type: :string, description: "Channel ID", example: "ch_123abc456def"},
        data: %Schema{
          type: :object,
          description: "Event payload data",
          additionalProperties: true
        },
        timestamp: %Schema{
          type: :string,
          format: "date-time",
          description: "Event timestamp in ISO 8601 format",
          example: "2024-01-15T10:30:00Z"
        },
        version: %Schema{type: :integer, description: "Event version", example: 1}
      },
      required: [:id, :type, :channel_id, :data, :timestamp],
      example: %{
        id: "evt_abc123def456",
        type: "message.created",
        channel_id: "ch_123abc456def",
        data: %{
          message_id: "msg_789",
          content: "Hello world"
        },
        timestamp: "2024-01-15T10:30:00Z",
        version: 1
      }
    })
  end

  defmodule EventHistoryResponse do
    @moduledoc """
    Response schema for event history
    """
    OpenApiSpex.schema(%{
      title: "EventHistoryResponse",
      description: "Event history response with pagination info",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean, description: "Operation success status"},
        data: %Schema{
          type: :array,
          description: "List of events",
          items: EventResponse
        },
        has_more: %Schema{
          type: :boolean,
          description: "Whether more events exist beyond the current page",
          example: true
        }
      },
      required: [:success, :data],
      example: %{
        success: true,
        data: [
          %{
            id: "evt_abc123def456",
            type: "message.created",
            channel_id: "ch_123abc456def",
            data: %{message_id: "msg_789", content: "Hello world"},
            timestamp: "2024-01-15T10:30:00Z",
            version: 1
          }
        ],
        has_more: false
      }
    })
  end

  defmodule SubscribeInfoResponse do
    @moduledoc """
    Response schema for subscription information
    """
    OpenApiSpex.schema(%{
      title: "SubscribeInfoResponse",
      description: "WebSocket subscription information",
      type: :object,
      properties: %{
        websocket_url: %Schema{
          type: :string,
          description: "WebSocket URL for real-time events",
          example: "/ws"
        },
        supported_events: %Schema{
          type: :array,
          description: "List of supported event types",
          items: %Schema{type: :string},
          example: [
            "message.created",
            "message.updated",
            "message.deleted",
            "user.presence",
            "typing.start",
            "typing.stop"
          ]
        }
      },
      required: [:websocket_url, :supported_events],
      example: %{
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
      }
    })
  end

  defmodule StatsData do
    @moduledoc """
    Broadcast statistics data
    """
    OpenApiSpex.schema(%{
      title: "StatsData",
      description: "Broadcast statistics data",
      type: :object,
      properties: %{
        total_events_24h: %Schema{
          type: :integer,
          description: "Total events in the last 24 hours",
          example: 125000
        },
        events_per_minute: %Schema{
          type: :number,
          format: :float,
          description: "Current events per minute rate",
          example: 87.5
        },
        active_channels: %Schema{
          type: :integer,
          description: "Number of active channels in the last hour",
          example: 450
        }
      },
      required: [:total_events_24h, :events_per_minute, :active_channels],
      example: %{
        total_events_24h: 125000,
        events_per_minute: 87.5,
        active_channels: 450
      }
    })
  end

  defmodule StatsResponse do
    @moduledoc """
    Response schema for broadcast statistics
    """
    OpenApiSpex.schema(%{
      title: "StatsResponse",
      description: "Broadcast statistics response",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean, description: "Operation success status"},
        data: StatsData
      },
      required: [:success, :data],
      example: %{
        success: true,
        data: %{
          total_events_24h: 125000,
          events_per_minute: 87.5,
          active_channels: 450
        }
      }
    })
  end
end
