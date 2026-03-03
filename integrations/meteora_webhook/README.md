# Meteora DLMM Webhook Service

Real-time Discord alerts for Meteora DLMM pool events.

## Setup

```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Configuration

Environment variables:
- `DISCORD_METEORA_WEBHOOK_URL`: Discord webhook URL (required)
- `METEORA_WEBHOOK_HOST`: Host to bind (default: 0.0.0.0)
- `METEORA_WEBHOOK_PORT`: Port to bind (default: 8080)
- `METEORA_RATE_LIMIT`: Messages per minute (default: 5)
- `METEORA_LOG_LEVEL`: Logging level (default: INFO)

## Run

```bash
python -m meteora_webhook.server
```

Or:

```bash
python -m meteora_webhook
```

## Usage

POST JSON to `/webhooks/meteora`:

```json
{
  "event_type": "new_pool",
  "pool_address": "0x...",
  "baseMint": "SOL...",
  "quoteMint": "USDC...",
  "liquidityUsd": 50000,
  "volume24h": 12000,
  "feeTier": 0.25,
  "apy": 85.5
}
```

## Event Types

- `new_pool`: New DLMM pool detected
- `volume_spike`: Unusual volume surge
- `fee_arbitrage`: Low fee opportunity
- `generic_opportunity`: Other favorable condition

## Testing

```bash
pytest -v
```