"""aiohttp web server for Meteora webhook endpoint."""
import asyncio
import logging
import os
from typing import Dict, Any

import aiohttp
from aiohttp import web

from .formatter import format_embed
from .sender import send_discord_embed, RateLimiter

logger = logging.getLogger(__name__)

def require_env(name: str) -> str:
    val = os.getenv(name)
    if not val:
        raise ValueError(f"Missing required env var: {name}")
    return val

class MeteoraWebhookServer:
    def __init__(self):
        self.discord_webhook_url = require_env("DISCORD_METEORA_WEBHOOK_URL")
        self.host = os.getenv("METEORA_WEBHOOK_HOST", "0.0.0.0")
        self.port = int(os.getenv("METEORA_WEBHOOK_PORT", "8080"))
        self.rate_limit = int(os.getenv("METEORA_RATE_LIMIT", "5"))
        self.rate_limiter = RateLimiter(rate=self.rate_limit)
        self.session: Optional[aiohttp.ClientSession] = None
        self.runner: Optional[web.AppRunner] = None

    async def start(self):
        """Initialize and start the web server."""
        self.session = aiohttp.ClientSession()
        app = web.Application()
        app.router.add_post("/webhooks/meteora", self.handle_meteora)
        app.router.add_get("/health", self.handle_health)

        self.runner = web.AppRunner(app)
        await self.runner.setup()
        site = web.TCPSite(self.runner, self.host, self.port)
        logger.info(f"Starting Meteora webhook server on {self.host}:{self.port}")
        await site.start()

    async def stop(self):
        """Shutdown the server gracefully."""
        if self.runner:
            await self.runner.cleanup()
        if self.session:
            await self.session.close()

    async def handle_health(self, request: web.Request) -> web.Response:
        """Health check endpoint."""
        return web.json_response({"status": "ok", "service": "meteora-webhook"})

    async def handle_meteora(self, request: web.Request) -> web.Response:
        """Accept Meteora event, format, and forward to Discord."""
        try:
            event = await request.json()
        except Exception as e:
            logger.error(f"Invalid JSON: {e}")
            return web.json_response({"error": "invalid json"}, status=400)

        # Validate required fields
        required = ["event_type", "pool_address", "baseMint", "quoteMint", "liquidityUsd", "volume24h", "feeTier", "apy"]
        missing = [k for k in required if k not in event]
        if missing:
            logger.warning(f"Missing fields: {missing}")
            return web.json_response({"error": f"missing fields: {missing}"}, status=400)

        # Log receipt
        logger.info(f"Received Meteora event: {event['event_type']} pool={event['pool_address'][:8]}...")

        # Format embed
        try:
            embed = format_embed(event)
        except Exception as e:
            logger.error(f"Failed to format embed: {e}", exc_info=True)
            return web.json_response({"error": "formatting failed"}, status=500)

        # Send to Discord
        success = await send_discord_embed(
            webhook_url=self.discord_webhook_url,
            embed=embed,
            session=self.session,
            max_retries=3,
            rate_limiter=self.rate_limiter
        )

        if success:
            return web.json_response({"status": "delivered"})
        else:
            return web.json_response({"error": "failed to deliver to Discord"}, status=500)

async def main():
    """Entry point for running the server."""
    logging.basicConfig(
        level=os.getenv("METEORA_LOG_LEVEL", "INFO"),
        format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
        datefmt="%H:%M:%S"
    )
    server = MeteoraWebhookServer()
    try:
        await server.start()
        # Keep running forever
        while True:
            await asyncio.sleep(3600)
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        await server.stop()
    except Exception as e:
        logger.error(f"Server crashed: {e}", exc_info=True)
        await server.stop()
        raise

if __name__ == "__main__":
    asyncio.run(main())