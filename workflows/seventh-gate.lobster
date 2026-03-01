name: seventh-gate
description: "Safe gateway restart - pre-flight checks, session cleanup, approval, restart, verify"
steps:
  - id: preflight
    description: "Pre-restart checks and session cleanup (dry run)"
    command: fleet pre-restart --json
    timeoutMs: 30000

  - id: review
    description: "Review pre-restart report"
    command: |
      echo "========================================="
      echo "  SEVENTH GATE - SAFE RESTART"
      echo "========================================="
      echo ""
      fleet format pre-restart-report
      echo ""
      echo "Approve to clean sessions and restart gateway."
    stdin: $preflight.stdout
    approval: required
    timeoutMs: 10000

  - id: cleanup
    description: "Execute session cleanup"
    command: fleet pre-restart --json --execute
    timeoutMs: 30000

  - id: stop_gateway
    description: "Stop the gateway"
    command: |
      systemctl --user stop openclaw-gateway 2>&1
      sleep 2
      if systemctl --user is-active openclaw-gateway >/dev/null 2>&1; then
        echo "ERROR: Gateway still running"
        exit 1
      fi
      echo "Gateway stopped"
    timeoutMs: 15000

  - id: start_gateway
    description: "Start the gateway"
    command: |
      systemctl --user start openclaw-gateway 2>&1
      sleep 3
      if ! systemctl --user is-active openclaw-gateway >/dev/null 2>&1; then
        echo "ERROR: Gateway failed to start"
        systemctl --user status openclaw-gateway 2>&1 | tail -10
        exit 1
      fi
      echo "Gateway started"
    timeoutMs: 15000

  - id: verify
    description: "Verify health after restart"
    command: |
      sleep 5
      fleet health --json | fleet format
      echo ""
      echo "=== SEVENTH GATE COMPLETE ==="
    timeoutMs: 20000
