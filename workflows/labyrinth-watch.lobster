name: labyrinth-watch
description: "Issue triage dashboard - scan all repos for stale, unassigned, or blocked issues"
args:
  stale_days:
    description: "Days since last update to consider stale"
    type: integer
    default: 14
steps:
  - id: scan
    description: "Fetch open issues from all repos"
    command: fleet issue-scan --json --stale-days ${stale_days}
    timeoutMs: 90000

  - id: report
    description: "Format issue report"
    command: fleet format issue-report
    stdin: $scan.stdout
    timeoutMs: 10000
