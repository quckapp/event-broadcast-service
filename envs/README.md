# Environment Configuration

This folder contains environment-specific configuration files for the Event Broadcast Service.

## Available Environments

| File | Environment | Description |
|------|-------------|-------------|
| `dev.env` | Development | Local development with debug logging |
| `test.env` | Test | Automated testing with isolated databases |
| `staging.env` | Staging | Pre-production environment |
| `prod.env` | Production | Production environment with secrets from vault |
| `docker.env` | Docker | Docker Compose local development |

## Usage

### Local Development

```bash
cp envs/dev.env .env
mix phx.server
```

### Docker Development

```bash
docker-compose --env-file envs/docker.env up
```

## Service-Specific Variables

### Event Configuration

- `EVENT_RETENTION_DAYS` - How long to keep events in the database
- `MAX_BATCH_SIZE` - Maximum events per batch
- `EVENT_PROCESSING_INTERVAL_MS` - Processing interval in milliseconds
