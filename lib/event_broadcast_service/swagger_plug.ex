defmodule EventBroadcastService.SwaggerPlug do
  @moduledoc """
  Plug for serving Swagger UI and OpenAPI specification.

  This plug serves the Swagger UI at /swagger and the OpenAPI spec at /api/v1/openapi.
  Since this service uses Plug.Router instead of Phoenix, we need to handle
  the Swagger UI serving manually.
  """
  use Plug.Router

  plug :match
  plug :dispatch

  # Root path handler - when forwarded from /swagger or /api/v1/openapi
  # the path prefix is stripped, so we match on "/"
  get "/" do
    # Check the original request path to determine what to serve
    case conn.request_path do
      "/api/v1/openapi" ->
        serve_openapi_spec(conn)

      path when path in ["/swagger", "/swagger/"] ->
        serve_swagger_ui(conn)

      _ ->
        # Fallback - serve based on what makes sense
        serve_swagger_ui(conn)
    end
  end

  # Catch trailing slash
  get "" do
    case conn.request_path do
      "/api/v1/openapi" ->
        serve_openapi_spec(conn)

      _ ->
        serve_swagger_ui(conn)
    end
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  defp serve_openapi_spec(conn) do
    spec = EventBroadcastService.ApiSpec.spec()
    json = Jason.encode!(spec)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, json)
  end

  defp serve_swagger_ui(conn) do
    html = swagger_ui_html()

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  defp swagger_ui_html do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Event Broadcast Service API - Swagger UI</title>
      <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css">
      <style>
        html {
          box-sizing: border-box;
          overflow: -moz-scrollbars-vertical;
          overflow-y: scroll;
        }
        *,
        *:before,
        *:after {
          box-sizing: inherit;
        }
        body {
          margin: 0;
          background: #fafafa;
        }
        .swagger-ui .topbar {
          background-color: #1a1a2e;
        }
        .swagger-ui .topbar .download-url-wrapper .select-label {
          color: #fff;
        }
        .swagger-ui .info .title {
          color: #1a1a2e;
        }
        .swagger-ui .scheme-container {
          background: #fff;
          box-shadow: 0 1px 2px 0 rgba(0,0,0,.15);
        }
      </style>
    </head>
    <body>
      <div id="swagger-ui"></div>
      <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
      <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-standalone-preset.js"></script>
      <script>
        window.onload = function() {
          const ui = SwaggerUIBundle({
            url: "/api/v1/openapi",
            dom_id: '#swagger-ui',
            deepLinking: true,
            presets: [
              SwaggerUIBundle.presets.apis,
              SwaggerUIStandalonePreset
            ],
            plugins: [
              SwaggerUIBundle.plugins.DownloadUrl
            ],
            layout: "StandaloneLayout",
            validatorUrl: null,
            supportedSubmitMethods: ['get', 'post', 'put', 'delete', 'patch'],
            defaultModelsExpandDepth: 1,
            defaultModelExpandDepth: 1,
            displayRequestDuration: true,
            filter: true,
            showExtensions: true,
            showCommonExtensions: true
          });
          window.ui = ui;
        };
      </script>
    </body>
    </html>
    """
  end
end
