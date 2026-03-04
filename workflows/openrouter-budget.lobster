name: openrouter-budget
description: "Check OpenRouter daily budget status fleet-wide. Shows per-model spend, remaining budget, and exhaustion status."
args:
  format:
    description: "Output format: text or json"
    type: string
    default: "text"
steps:
  - id: check_budget
    description: "Query OpenRouter budget proxy on all servers"
    command: |
      if [ "${format}" = "json" ]; then
        /data/openclaw/scripts/shared/openrouter-budget-check.sh --json
      else
        /data/openclaw/scripts/shared/openrouter-budget-check.sh
      fi
    timeoutMs: 30000
