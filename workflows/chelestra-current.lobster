name: chelestra-current
description: "Fleet maintenance - disk, sessions, cache, journal across local server"
steps:
  - id: maint
    description: "Run maintenance check"
    command: fleet maintenance --json
    timeoutMs: 30000

  - id: sessions
    description: "Check session sizes"
    command: fleet sessions --json
    timeoutMs: 15000

  - id: report
    description: "Format maintenance report"
    command: |
      echo "========================================="
      echo "  CHELESTRA CURRENT - FLEET MAINTENANCE"
      echo "========================================="
      echo ""
      fleet format maintenance-report
      echo ""
      echo "Run: $(date -u '+%Y-%m-%d %H:%M UTC')"
    stdin: $maint.stdout
    timeoutMs: 10000
