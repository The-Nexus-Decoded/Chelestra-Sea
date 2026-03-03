"""Tests for sender rate limiting and retry logic."""
import asyncio
import time
import pytest
from meteora_webhook.sender import RateLimiter, send_discord_embed

@pytest.mark.asyncio
async def test_rate_limiter_initial():
    limiter = RateLimiter(rate=5)  # 5 per minute
    # Initially should have tokens available (replenish)
    assert limiter.consume() is True
    # Consume remaining quickly
    for _ in range(4):
        assert limiter.consume() is True
    # Should be blocked now
    assert limiter.consume() is False

@pytest.mark.asyncio
async def test_rate_limiter_replenish():
    limiter = RateLimiter(rate=2)  # 2 per minute
    assert limiter.consume() is True
    assert limiter.consume() is True
    assert limiter.consume() is False
    # Wait for replenishment (30 seconds for 1 token at 2/min)
    await asyncio.sleep(31)
    assert limiter.consume() is True

@pytest.mark.asyncio
async def test_send_discord_embed_success(monkeypatch):
    class MockResponse:
        status = 204
        async def __aenter__(self): return self
        async def __aexit__(self, *args): pass
        async def text(self): return ""

    class MockSession:
        async def __aenter__(self): return self
        async def __aexit__(self, *args): pass
        def post(self, url, **kwargs):
            assert url == "https://discord.com/api/webhooks/test"
            assert "json" in kwargs
            return MockResponse()

    embed = {"title": "test", "description": "test"}
    session = MockSession()
    success = await send_discord_embed("https://discord.com/api/webhooks/test", embed, session=session)
    assert success is True

@pytest.mark.asyncio
async def test_send_discord_embed_429_retry(monkeypatch):
    call_count = 0
    class MockResponse:
        status = 429
        async def __aenter__(self): return self
        async def __aexit__(self, *args): pass
        async def text(self):
            if self.status == 429:
                return "2.0"
            return ""

    class MockSession:
        async def __aenter__(self): return self
        async def __aexit__(self, *args): pass
        def post(self, url, **kwargs):
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                resp = MockResponse()
                resp.status = 429
                return resp
            resp = MockResponse()
            resp.status = 204
            return resp

    embed = {"title": "test"}
    session = MockSession()
    success = await send_discord_embed("https://test", embed, session=session, max_retries=2)
    assert success is True
    assert call_count == 2  # retry succeeded

@pytest.mark.asyncio
async def test_send_discord_embed_400_no_retry(monkeypatch):
    class MockResponse:
        status = 400
        async def __aenter__(self): return self
        async def __aexit__(self, *args): pass
        async def text(self): return "bad request"

    class MockSession:
        async def __aenter__(self): return self
        async def __aexit__(self, *args): pass
        def post(self, url, **kwargs):
            return MockResponse()

    embed = {"title": "test"}
    session = MockSession()
    success = await send_discord_embed("https://test", embed, session=session, max_retries=3)
    assert success is False  # 400 is not retried