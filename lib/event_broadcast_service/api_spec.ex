defmodule EventBroadcastService.ApiSpec do
  @moduledoc """
  OpenAPI specification for Event Broadcast Service.

  This module defines the complete OpenAPI 3.0 specification for the Event Broadcast Service API.
  Since the service uses Plug.Router instead of Phoenix, paths are defined manually.
  """
  alias OpenApiSpex.{
    Components,
    Info,
    MediaType,
    OpenApi,
    Operation,
    Parameter,
    PathItem,
    RequestBody,
    Response,
    Schema,
    SecurityScheme,
    Server
  }

  alias EventBroadcastService.Schemas.Common
  alias EventBroadcastService.Schemas.Event

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "Event Broadcast Service API",
        description: "Real-time event broadcasting and distribution API",
        version: "1.0.0"
      },
      servers: [
        %Server{url: "/", description: "Current server"}
      ],
      paths: paths(),
      components: %Components{
        schemas: schemas(),
        securitySchemes: %{
          "bearerAuth" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            bearerFormat: "JWT",
            description: "JWT Bearer token authentication"
          },
          "apiKey" => %SecurityScheme{
            type: "apiKey",
            name: "X-API-Key",
            in: "header",
            description: "API Key authentication"
          }
        }
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end

  defp paths do
    %{
      "/health" => %PathItem{
        get: %Operation{
          tags: ["Health"],
          summary: "Health check",
          description: "Returns the health status of the service",
          operationId: "getHealth",
          responses: %{
            200 => %Response{
              description: "Health check response",
              content: %{"application/json" => %MediaType{schema: Common.HealthResponse}}
            }
          }
        }
      },
      "/health/ready" => %PathItem{
        get: %Operation{
          tags: ["Health"],
          summary: "Readiness check",
          description: "Returns the readiness status of the service including dependency checks for MongoDB and Redis",
          operationId: "getHealthReady",
          responses: %{
            200 => %Response{
              description: "Service is ready",
              content: %{"application/json" => %MediaType{schema: Common.ReadinessResponse}}
            },
            503 => %Response{
              description: "Service is not ready",
              content: %{"application/json" => %MediaType{schema: Common.ReadinessResponse}}
            }
          }
        }
      },
      "/health/live" => %PathItem{
        get: %Operation{
          tags: ["Health"],
          summary: "Liveness check",
          description: "Returns the liveness status of the service",
          operationId: "getHealthLive",
          responses: %{
            200 => %Response{
              description: "Service is live",
              content: %{"application/json" => %MediaType{schema: Common.LivenessResponse}}
            }
          }
        }
      },
      "/api/v1/broadcast" => %PathItem{
        post: %Operation{
          tags: ["Broadcasting"],
          summary: "Broadcast event",
          description: "Broadcasts an event to all subscribers of the specified channel. The event is stored in MongoDB for history, published to Redis for real-time subscribers, and sent to Kafka for other services.",
          operationId: "broadcastEvent",
          security: [%{"bearerAuth" => []}, %{"apiKey" => []}],
          requestBody: %RequestBody{
            description: "Event to broadcast",
            required: true,
            content: %{"application/json" => %MediaType{schema: Event.BroadcastEventRequest}}
          },
          responses: %{
            200 => %Response{
              description: "Event broadcast successfully",
              content: %{"application/json" => %MediaType{schema: Common.SuccessResponse}}
            },
            400 => %Response{
              description: "Invalid request",
              content: %{"application/json" => %MediaType{schema: Common.ErrorResponse}}
            }
          }
        }
      },
      "/api/v1/broadcast/targeted" => %PathItem{
        post: %Operation{
          tags: ["Broadcasting"],
          summary: "Targeted broadcast",
          description: "Broadcasts an event to specific targets (users, channels, or workspaces) instead of a general channel broadcast",
          operationId: "broadcastTargeted",
          security: [%{"bearerAuth" => []}, %{"apiKey" => []}],
          requestBody: %RequestBody{
            description: "Targeted broadcast request",
            required: true,
            content: %{"application/json" => %MediaType{schema: Event.TargetedBroadcastRequest}}
          },
          responses: %{
            200 => %Response{
              description: "Event broadcast successfully",
              content: %{"application/json" => %MediaType{schema: Common.SuccessResponse}}
            },
            400 => %Response{
              description: "Invalid request",
              content: %{"application/json" => %MediaType{schema: Common.ErrorResponse}}
            }
          }
        }
      },
      "/api/v1/events/{channel_id}" => %PathItem{
        get: %Operation{
          tags: ["Events"],
          summary: "Get event history",
          description: "Retrieves the event history for a specific channel from MongoDB, sorted by timestamp in descending order",
          operationId: "getEventHistory",
          security: [%{"bearerAuth" => []}, %{"apiKey" => []}],
          parameters: [
            %Parameter{
              name: "channel_id",
              in: :path,
              required: true,
              description: "Channel ID to get history for",
              schema: %Schema{type: :string},
              example: "ch_123abc456def"
            },
            %Parameter{
              name: "limit",
              in: :query,
              required: false,
              description: "Maximum number of events to return (default: 50, max: 1000)",
              schema: %Schema{type: :integer, minimum: 1, maximum: 1000, default: 50},
              example: 50
            }
          ],
          responses: %{
            200 => %Response{
              description: "Event history",
              content: %{"application/json" => %MediaType{schema: Event.EventHistoryResponse}}
            }
          }
        }
      },
      "/api/v1/subscribe/info" => %PathItem{
        get: %Operation{
          tags: ["Subscription"],
          summary: "Get subscription info",
          description: "Returns WebSocket connection information and the list of supported event types for real-time subscriptions",
          operationId: "getSubscribeInfo",
          responses: %{
            200 => %Response{
              description: "Subscription information",
              content: %{"application/json" => %MediaType{schema: Event.SubscribeInfoResponse}}
            }
          }
        }
      },
      "/api/v1/stats" => %PathItem{
        get: %Operation{
          tags: ["Statistics"],
          summary: "Get broadcast stats",
          description: "Returns statistics about event broadcasting including total events in the last 24 hours, current events per minute rate, and number of active channels",
          operationId: "getStats",
          security: [%{"bearerAuth" => []}, %{"apiKey" => []}],
          responses: %{
            200 => %Response{
              description: "Broadcast statistics",
              content: %{"application/json" => %MediaType{schema: Event.StatsResponse}}
            }
          }
        }
      }
    }
  end

  defp schemas do
    %{
      "HealthResponse" => Common.HealthResponse,
      "ReadinessResponse" => Common.ReadinessResponse,
      "LivenessResponse" => Common.LivenessResponse,
      "SuccessResponse" => Common.SuccessResponse,
      "ErrorResponse" => Common.ErrorResponse,
      "NotFoundResponse" => Common.NotFoundResponse,
      "BroadcastEventRequest" => Event.BroadcastEventRequest,
      "TargetedBroadcastRequest" => Event.TargetedBroadcastRequest,
      "BroadcastTarget" => Event.BroadcastTarget,
      "EventMetadata" => Event.EventMetadata,
      "EventResponse" => Event.EventResponse,
      "EventHistoryResponse" => Event.EventHistoryResponse,
      "SubscribeInfoResponse" => Event.SubscribeInfoResponse,
      "StatsResponse" => Event.StatsResponse,
      "StatsData" => Event.StatsData
    }
  end
end
