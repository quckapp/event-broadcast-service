defmodule EventBroadcastService.MixProject do
  use Mix.Project

  @production_envs [:prod, :production, :staging, :live, :qa, :uat1, :uat2, :uat3]

  def project do
    [
      app: :event_broadcast_service,
      version: "1.0.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() in @production_envs,
      deps: deps(),
      releases: [
        event_broadcast_service: [
          include_executables_for: [:unix],
          applications: [runtime_tools: :permanent]
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {EventBroadcastService.Application, []}
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.7.10"},
      {:phoenix_pubsub, "~> 2.1"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.6"},
      {:cors_plug, "~> 3.0"},
      {:mongodb_driver, "~> 1.4"},
      {:castore, "~> 1.0"},
      {:redix, "~> 1.3"},
      {:phoenix_pubsub_redis, "~> 3.0"},
      {:brod, "~> 3.16"},
      {:finch, "~> 0.18"},
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:libcluster, "~> 3.3"},
      {:timex, "~> 3.7"},
      {:uuid, "~> 1.1"},
      {:open_api_spex, "~> 3.18"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},

      # Algorithm libraries
      {:fuse, "~> 2.5"},
      {:flow, "~> 1.2"}
    ]
  end
end
