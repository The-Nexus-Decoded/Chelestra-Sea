name: abarrach-stone
description: "Memory consolidation - gather workspace memory files and health data for review"
steps:
  - id: memory
    description: "Gather workspace memory files"
    command: fleet memory --json
    timeoutMs: 15000

  - id: health
    description: "Get rate guard health"
    command: fleet health --json
    timeoutMs: 15000

  - id: review
    description: "Review memory and health data"
    command: |
      echo "========================================="
      echo "  ABARRACH STONE - MEMORY CONSOLIDATION"
      echo "========================================="
      echo ""
      fleet format memory-report
      echo ""
      echo "--- HEALTH ---"
      echo ""
      echo "Approve to proceed with memory consolidation."
    stdin: $memory.stdout
    approval: required
    timeoutMs: 10000
