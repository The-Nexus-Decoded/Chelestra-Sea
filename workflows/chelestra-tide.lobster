name: chelestra-tide
description: "Post-OpenClaw-update patch reapply with verification"
steps:
  - id: check_patches
    description: "Check current patch status"
    command: fleet patch-status --json
    timeoutMs: 15000

  - id: review
    description: "Review patch status before reapply"
    command: |
      echo "========================================="
      echo "  CHELESTRA TIDE - POST-UPDATE PATCHES"
      echo "========================================="
      echo ""
      fleet format patch-report
      echo ""
      echo "Approve to reapply patches and restart services."
    stdin: $check_patches.stdout
    approval: required
    timeoutMs: 10000

  - id: reapply
    description: "Reapply vendor patches"
    command: |
      if [ -f /data/openclaw/rate-guard-v2/reapply-rate-guard-patches.sh ]; then
        sudo bash /data/openclaw/rate-guard-v2/reapply-rate-guard-patches.sh 2>&1
        echo "Patches reapplied"
      else
        echo "ERROR: reapply script not found"
        exit 1
      fi
    timeoutMs: 60000

  - id: clear_cache
    description: "Clear node compile cache"
    command: |
      rm -rf ~/.cache/node/compile_cache 2>/dev/null
      echo "Compile cache cleared"
    timeoutMs: 10000

  - id: restart_confirm
    description: "Confirm before restarting services"
    command: |
      echo "Patches reapplied and cache cleared."
      echo "Approve to restart rate guard and gateway."
    approval: required
    timeoutMs: 10000

  - id: restart
    description: "Restart rate guard and gateway"
    command: |
      systemctl --user restart openclaw-rate-guard 2>&1
      echo "Rate guard restarted"
      sleep 2
      systemctl --user restart openclaw-gateway 2>&1
      echo "Gateway restarted"
      sleep 5
    timeoutMs: 30000

  - id: verify
    description: "Verify health after restart"
    command: |
      fleet health --json | fleet format
      echo ""
      fleet patch-status --json | fleet format
      echo ""
      echo "=== CHELESTRA TIDE COMPLETE ==="
    timeoutMs: 20000
