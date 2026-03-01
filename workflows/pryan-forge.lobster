name: pryan-forge
description: "PR review monitor - scans all repos for unreviewed PRs"
steps:
  - id: scan
    description: "Fetch open PRs from all repos"
    command: fleet pr-scan --json
    timeoutMs: 60000

  - id: report
    description: "Format PR report"
    command: fleet format pr-report
    stdin: $scan.stdout
    timeoutMs: 10000
