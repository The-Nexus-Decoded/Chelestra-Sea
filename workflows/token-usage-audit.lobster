name: token-usage-audit
description: "Audit rate guard health and token usage across fleet servers"
steps:
  - id: health
    description: "Check rate guard health"
    command: fleet health --json
    timeoutMs: 15000

  - id: sessions
    description: "Check session sizes"
    command: fleet sessions --json
    timeoutMs: 15000

  - id: report
    description: "Format audit report"
    command: |
      echo "========================================="
      echo "  TOKEN USAGE AUDIT"
      echo "========================================="
      echo ""
      fleet format health-report
      echo ""
      echo "--- SESSIONS ---"
      echo ""
      fleet format sessions-report
    stdin: $health.stdout
    timeoutMs: 10000
