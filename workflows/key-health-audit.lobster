name: key-health-audit
description: "Fleet-wide API key health audit. Checks per-key success rates, flags unhealthy keys, reports active cooldowns. Pure CLI, zero LLM calls."
steps:
  - id: audit
    description: "Audit API key health across all servers"
    command: |
      bash /data/openclaw/scripts/shared/key-health-audit.sh
    timeoutMs: 30000
