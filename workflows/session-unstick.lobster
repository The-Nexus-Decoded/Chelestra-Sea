name: session-unstick
description: "Unstick a stuck agent session. Backs up sessions.json, removes channel mapping, clears locks, restarts gateway. Pure CLI, zero LLM calls."
args:
  server:
    description: "Target server: zifnab, haplo, or hugh"
    type: string
  channel_id:
    description: "Discord channel ID to unstick, or --list to show current mappings"
    type: string
steps:
  - id: unstick
    description: "Unstick session (dry run by default, add --execute to args for live fix)"
    command: |
      bash /data/openclaw/scripts/shared/session-unstick.sh "${server}" "${channel_id}"
    timeoutMs: 30000
