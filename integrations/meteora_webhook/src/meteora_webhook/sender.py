"""Discord sender with rate limiting and retry logic.""" 
import asyncio
import logging
import time
from dataclasses import dataclass, field
from typing import Any, Dict, Optional

import aiohttp

logger = logging.getLogger(__name__)

@dataclass
class RateLimiter:
    """Simple token bucket rate limiter."""
    rate: int  # messages per minute
    tokens: float = field(init=False)
    last_update: float = field(default_factory=time.time)

    def __post_init__(self):
        # Start with full tokens for initial burst
        self.tokens = float(self.rate)

    def consume(self) -> bool:
        """Consume a token if available, return True if allowed."""
        now = time.time()
        # Replenish tokens based on time passed
        delta = (now - self.last_update) / 60.0  # minutes
        self.tokens = min(self.rate, self.tokens + delta * self.rate)
        self.last_update = now

        if self.tokens >= 1:
            self.tokens -= 1
            return True
        return False

async def send_discord_embed(
    webhook_url: str,
    embed: Dict[str, Any],
    session: Optional[aiohttp.ClientSession] = None,
    max_retries: int = 3,
    rate_limiter: Optional[RateLimiter] = None
) -> bool:
    """
    Send embed to Discord webhook with retry and rate limiting.
    Returns True on success, False on permanent failure.
    """
    # Rate limit check
    if rate_limiter and not rate_limiter.consume():
        wait_time = 60 / rate_limiter.rate
        logger.warning(f"Rate limited, sleeping {wait_time:.1f}s")
        await asyncio.sleep(wait_time)
        # Retry once after waiting
        if rate_limiter.consume():
            pass
        else:
            return False

    # Prepare payload
    payload = {"embeds": [embed]}

    # Use provided session or create temporary
    should_close = session is None
    if should_close:
        session = aiohttp.ClientSession()

    try:
        for attempt in range(1, max_retries + 1):
            try:
                async with session.post(webhook_url, json=payload, timeout=10) as resp:
                    if resp.status in (200, 204):
                        logger.info(f"Discord webhook delivered (attempt {attempt})")
                        return True
                    elif resp.status == 429:  # rate limited by Discord
                        retry_after = float(await resp.text()) or 5.0
                        logger.warning(f"Discord rate limit hit, waiting {retry_after}s")
                        await asyncio.sleep(retry_after)
                        continue
                    else:
                        text = await resp.text()
                        logger.error(f"Discord webhook failed: HTTP {resp.status}: {text[:200]}")
                        if resp.status in (400, 403):  # client error, don't retry
                            return False
            except asyncio.TimeoutError:
                logger.warning(f"Timeout on attempt {attempt}")
            except Exception as e:
                logger.error(f"Error on attempt {attempt}: {e}", exc_info=True)

            if attempt < max_retries:
                backoff = 2 ** attempt
                logger.info(f"Retrying in {backoff}s...")
                await asyncio.sleep(backoff)

        logger.error("Max retries exceeded")
        return False

    finally:
        if should_close and session:
            await session.close()