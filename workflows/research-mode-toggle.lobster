name: research-mode-toggle
description: "Toggle research mode fleet-wide or on a single server. Wraps research-mode.sh. Pure CLI, zero LLM calls."
args:
  action:
    description: "on (pro-first), off (flash-first), or status"
    type: string
    default: "status"
  target:
    description: "Server: zifnab, haplo, hugh, or all"
    type: string
    default: "all"
steps:
  - id: toggle
    description: "Toggle research mode"
    command: |
      bash /data/openclaw/scripts/shared/research-mode-toggle.sh "${action}" "${target}"
    timeoutMs: 30000
