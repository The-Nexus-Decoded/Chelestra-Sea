name: zifnab-memory-maintenance
description: "Workflow for distilling recent daily memory files and achieving continuity for Lord Xar."
args:
  days_back:
    description: "Number of days back to collect memory files."
    type: integer
    default: 2
steps:
  - id: dates
    description: "Calculate dates for the lookback period."
    command: |
      # Generate list of dates in YYYY-MM-DD format
      for i in $(seq 0 $(({args.days_back} - 1))); do
        date -d "$i days ago" +%Y-%m-%d
      done
  - id: fetch_logs
    description: "Gather content from recent memory files."
    command: |
      echo "--- START MEMORY COLLECTION ---"
      while read -r d; do
        if [ -f "/data/openclaw/workspace/memory/$d.md" ]; then
          echo "### DATE: $d"
          cat "/data/openclaw/workspace/memory/$d.md"
          echo -e "\n---\n"
        fi
      done <<EOF
      {dates.stdout}
      EOF
      echo "--- END MEMORY COLLECTION ---"
  - id: status_check
    description: "Capture the current fleet heartbeat status."
    command: |
      echo "### FLEET STATUS SNAPSHOT"
      curl -s http://localhost:8787/health | jq -C . || echo "Rate Guard unreachable."
  - id: finalize_for_distillation
    description: "Consolidate everything for the coordinator's review."
    command: |
      echo "## MEMORY MAINTENANCE REPORT"
      echo "Refining continuity for the Lord of the Patryns..."
      echo ""
      echo "{fetch_logs.stdout}"
      echo ""
      echo "{status_check.stdout}"
    approval: required
