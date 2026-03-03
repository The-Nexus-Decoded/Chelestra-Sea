"""Discord embed formatter for Meteora events.""" 
import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)

# Event type styling
EVENT_STYLE = {
    "new_pool": {"color": 0x00FF00, "emoji": "🆕", "title": "New Meteora DLMM Pool Detected"},
    "volume_spike": {"color": 0xFFA500, "emoji": "🚀", "title": "Volume Spike Alert"},
    "fee_arbitrage": {"color": 0x0000FF, "emoji": "💰", "title": "Fee Arbitrage Opportunity"},
    "generic_opportunity": {"color": 0x808080, "emoji": "⚖️", "title": "Generic Opportunity"},
}

def format_embed(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Create a Discord embed from a Meteora event.
    Required keys: event_type, pool_address, baseMint, quoteMint, liquidityUsd, volume24h, feeTier, apy
    """
    event_type = event.get("event_type", "generic_opportunity")
    style = EVENT_STYLE.get(event_type, EVENT_STYLE["generic_opportunity"])

    # Extract fields with safe fallbacks
    pool_address = event.get("pool_address", "N/A")
    base_mint = event.get("baseMint", "N/A")
    quote_mint = event.get("quoteMint", "N/A")
    liquidity = float(event.get("liquidityUsd", 0))
    volume = float(event.get("volume24h", 0))
    fee_tier = float(event.get("feeTier", 0))
    apy = float(event.get("apy", 0))

    # Truncate mint addresses for display
    short_base = base_mint[:6] + "..." if len(base_mint) > 6 else base_mint
    short_quote = quote_mint[:6] + "..." if len(quote_mint) > 6 else quote_mint
    short_pool = pool_address[:8] + "..." if len(pool_address) > 8 else pool_address

    # Build description with key metrics
    description = (
        f"**Pool:** `{short_pool}`\n"
        f"**Pair:** {short_base}/{short_quote}\n"
        f"**Liquidity:** ${liquidity:,.2f}\n"
        f"**Volume 24h:** ${volume:,.2f}\n"
        f"**Fee Tier:** {fee_tier:.2f}%\n"
        f"**APY:** {apy:.2f}%"
    )

    embed = {
        "title": f"{style['emoji']} {style['title']}",
        "description": description,
        "color": style["color"],
        "fields": [
            {"name": "Base Mint", "value": f"`{base_mint}`", "inline": True},
            {"name": "Quote Mint", "value": f"`{quote_mint}`", "inline": True},
            {"name": "Pool Address", "value": f"`{pool_address}`", "inline": False},
        ],
        "timestamp": event.get("timestamp")  # optional ISO 8601
    }

    return embed