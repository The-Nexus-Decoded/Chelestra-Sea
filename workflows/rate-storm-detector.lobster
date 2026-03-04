name: rate-storm-detector
description: "Detect 429 rate storms across the fleet. Checks recent 429 rate, alerts if above threshold, shows hotspot keys/models. Pure CLI, zero LLM calls."
steps:
  - id: detect
    description: "Scan for rate storms (last 15 minutes)"
    command: |
      bash /data/openclaw/scripts/shared/rate-storm-detector.sh
    timeoutMs: 30000
