"""Tests for the embed formatter.""" 
import pytest
from meteora_webhook.formatter import format_embed, EVENT_STYLE

def test_format_new_pool():
    event = {
        "event_type": "new_pool",
        "pool_address": "0x1234567890abcdef",
        "baseMint": "SOL",
        "quoteMint": "USDC",
        "liquidityUsd": 50000.0,
        "volume24h": 12000.0,
        "feeTier": 0.25,
        "apy": 85.5
    }
    embed = format_embed(event)
    assert embed["title"] == "🆕 New Meteora DLMM Pool Detected"
    assert embed["color"] == EVENT_STYLE["new_pool"]["color"]
    assert "SOL/USDC" in embed["description"]
    assert "$50,000.00" in embed["description"] or "50,000" in embed["description"]
    assert any(f["name"] == "Pool Address" for f in embed["fields"])

def test_format_volume_spike():
    event = {
        "event_type": "volume_spike",
        "pool_address": "0xabcd1234",
        "baseMint": "BONK",
        "quoteMint": "USDT",
        "liquidityUsd": 10000,
        "volume24h": 50000,
        "feeTier": 0.5,
        "apy": 120.0
    }
    embed = format_embed(event)
    assert embed["title"] == "🚀 Volume Spike Alert"
    assert embed["color"] == EVENT_STYLE["volume_spike"]["color"]

def test_format_generic():
    event = {
        "event_type": "generic_opportunity",
        "pool_address": "0xdeadbeef",
        "baseMint": "JUP",
        "quoteMint": "USDC",
        "liquidityUsd": 25000,
        "volume24h": 8000,
        "feeTier": 0.1,
        "apy": 45.2
    }
    embed = format_embed(event)
    assert embed["title"] == "⚖️ Generic Opportunity"
    assert embed["color"] == EVENT_STYLE["generic_opportunity"]["color"]

def test_format_unknown_event_type():
    event = {
        "event_type": "unknown_type",
        "pool_address": "0x123",
        "baseMint": "TEST",
        "quoteMint": "TEST",
        "liquidityUsd": 100,
        "volume24h": 200,
        "feeTier": 0.01,
        "apy": 1.0
    }
    embed = format_embed(event)
    assert embed["title"] == "⚖️ Generic Opportunity"  # fallback
    assert embed["color"] == EVENT_STYLE["generic_opportunity"]["color"]

def test_format_with_timestamp():
    event = {
        "event_type": "new_pool",
        "pool_address": "0x123",
        "baseMint": "SOL",
        "quoteMint": "USDC",
        "liquidityUsd": 1000,
        "volume24h": 2000,
        "feeTier": 0.2,
        "apy": 10.0,
        "timestamp": "2025-01-15T12:34:56Z"
    }
    embed = format_embed(event)
    assert "timestamp" in embed
    assert embed["timestamp"] == "2025-01-15T12:34:56Z"