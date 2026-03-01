name: token-usage-audit
description: "Audit token usage and Rate Guard budgets across the fleet servers."
steps:
  - id: audit_local
    description: "Check rate guard status on ola-claw-dev (local)"
    command: |
      echo "--- [ola-claw-dev] Rate Guard ---"
      systemctl --user status quota-monitor.timer | grep Active
      grep "exhaustedUntil" /data/openclaw/openclaw.json || echo "No active exhaustion."
  - id: audit_main
    description: "Check rate guard status on ola-claw-main (Zifnab)"
    command: |
      echo "--- [ola-claw-main] Rate Guard ---"
      ssh 100.103.189.117 "systemctl --user status quota-monitor.timer | grep Active; grep 'exhaustedUntil' /data/openclaw/openclaw.json || echo 'No active exhaustion.'"
  - id: audit_trade
    description: "Check rate guard status on ola-claw-trade (Hugh)"
    command: |
      echo "--- [ola-claw-trade] Rate Guard ---"
      ssh 100.104.166.53 "systemctl --user status quota-monitor.timer | grep Active; grep 'exhaustedUntil' /data/openclaw/openclaw.json || echo 'No active exhaustion.'"
