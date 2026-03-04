name: daily-cost-report
description: "Fleet-wide daily cost and usage report from rate-guard analytics. Queries all 3 servers, calculates estimated API costs. Pure CLI, zero LLM calls."
steps:
  - id: report
    description: "Generate fleet-wide cost report"
    command: |
      bash /data/openclaw/scripts/shared/daily-cost-report.sh
    timeoutMs: 30000
