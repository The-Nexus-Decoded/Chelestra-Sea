name: model-chain-swap
description: "Swap model priority chain in rate-guard config. Presets: flash-first, pro-first, research, balanced. Proxy hot-reloads. Pure CLI, zero LLM calls."
args:
  target:
    description: "Target server: zifnab, haplo, hugh, or all"
    type: string
  preset:
    description: "Chain preset: flash-first, pro-first, research, balanced, or --show to display current chains"
    type: string
steps:
  - id: swap
    description: "Swap model chain (dry run by default, add --execute to args for live swap)"
    command: |
      bash /data/openclaw/scripts/shared/model-chain-swap.sh "${target}" "${preset}"
    timeoutMs: 30000
