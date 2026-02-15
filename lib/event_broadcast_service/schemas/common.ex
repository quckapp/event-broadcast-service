defmodule EventBroadcastService.Schemas.Common do
  @moduledoc """
  Common schemas for API responses
  """
  alias OpenApiSpex.Schema
  require OpenApiSpex

  defmodule SuccessResponse do
    @moduledoc """
    Generic success response
    """
    OpenApiSpex.schema(%{
      title: "SuccessResponse",
      description: "Generic success response",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean, description: "Operation success status", example: true}
      },
      required: [:success],
      example: %{
        success: true
      }
    })
  end

  defmodule ErrorResponse do
    @moduledoc """
    Generic error response
    """
    OpenApiSpex.schema(%{
      title: "ErrorResponse",
      description: "Generic error response",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean, description: "Operation success status", example: false},
        error: %Schema{type: :string, description: "Error message", example: "Invalid request"}
      },
      required: [:success, :error],
      example: %{
        success: false,
        error: "Invalid request"
      }
    })
  end

  defmodule NotFoundResponse do
    @moduledoc """
    Not found error response
    """
    OpenApiSpex.schema(%{
      title: "NotFoundResponse",
      description: "Resource not found response",
      type: :object,
      properties: %{
        error: %Schema{type: :string, description: "Error message", example: "Not found"}
      },
      required: [:error],
      example: %{
        error: "Not found"
      }
    })
  end

  defmodule HealthResponse do
    @moduledoc """
    Health check response
    """
    OpenApiSpex.schema(%{
      title: "HealthResponse",
      description: "Health check response",
      type: :object,
      properties: %{
        status: %Schema{type: :string, description: "Service status", example: "healthy"},
        service: %Schema{type: :string, description: "Service name", example: "event-broadcast-service"}
      },
      required: [:status, :service],
      example: %{
        status: "healthy",
        service: "event-broadcast-service"
      }
    })
  end

  defmodule ReadinessResponse do
    @moduledoc """
    Readiness check response
    """
    OpenApiSpex.schema(%{
      title: "ReadinessResponse",
      description: "Readiness check response",
      type: :object,
      properties: %{
        ready: %Schema{type: :boolean, description: "Service readiness status"},
        checks: %Schema{
          type: :object,
          description: "Individual service checks",
          properties: %{
            mongo: %Schema{type: :string, enum: ["ok", "error"], description: "MongoDB connection status"},
            redis: %Schema{type: :string, enum: ["ok", "error"], description: "Redis connection status"}
          }
        }
      },
      required: [:ready, :checks],
      example: %{
        ready: true,
        checks: %{
          mongo: "ok",
          redis: "ok"
        }
      }
    })
  end

  defmodule LivenessResponse do
    @moduledoc """
    Liveness check response
    """
    OpenApiSpex.schema(%{
      title: "LivenessResponse",
      description: "Liveness check response",
      type: :object,
      properties: %{
        live: %Schema{type: :boolean, description: "Service liveness status"}
      },
      required: [:live],
      example: %{
        live: true
      }
    })
  end
end
