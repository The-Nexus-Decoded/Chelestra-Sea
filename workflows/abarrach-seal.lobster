name: abarrach-seal
description: "Stale branch cleanup - find merged or dead branches across repos, approval before deletion"
steps:
  - id: scan
    description: "Scan branches across all repos"
    command: fleet branch-scan --json
    timeoutMs: 120000

  - id: review
    description: "Review branches for cleanup"
    command: |
      echo "========================================="
      echo "  ABARRACH SEAL - BRANCH CLEANUP"
      echo "========================================="
      echo ""
      fleet format branch-report
      echo ""
      echo "Approve to delete MERGED and CLOSED branches."
    stdin: $scan.stdout
    approval: required
    timeoutMs: 10000

  - id: delete
    description: "Delete eligible branches"
    command: fleet branch-delete --json
    timeoutMs: 120000

  - id: result
    description: "Show deletion results"
    command: |
      cat
      echo ""
      echo "=== ABARRACH SEAL COMPLETE ==="
    stdin: $delete.stdout
    timeoutMs: 10000
