name: fleet-maintenance-status
description: "Automated log pruning, cache clearing, and status reporting across all fleet servers to optimize token usage."
args:
  log_retention_days:
    description: "Number of days of logs to retain."
    type: integer
    default: 7
steps:
  - id: maintenance_zifnab_local
    description: "Maintenance tasks on Zifnab (Local)."
    command: |
      echo "--- Zifnab (Local) Maintenance ---"
      # Prune user-level journal logs
      journalctl --user --vacuum-time={args.log_retention_days}d
      # Clear npm/yarn caches
      npm cache clean --force || true
      # Remove temp artifacts in workspace
      find /data/openclaw/workspace/tmp -mtime +1 -delete 2>/dev/null || true
      echo "Maintenance complete."
  - id: maintenance_haplo_ssh
    description: "Maintenance tasks on Haplo (SSH)."
    command: |
      ssh openclaw@100.94.203.10 "
        echo '--- Haplo (SSH) Maintenance ---';
        journalctl --user --vacuum-time={args.log_retention_days}d;
        npm cache clean --force || true;
        find /data/openclaw/workspace/tmp -mtime +1 -delete 2>/dev/null || true;
        echo 'Maintenance complete.';
      "
  - id: maintenance_hugh_ssh
    description: "Maintenance tasks on Hugh (SSH)."
    command: |
      ssh openclaw@100.104.166.53 "
        echo '--- Hugh (SSH) Maintenance ---';
        journalctl --user --vacuum-time={args.log_retention_days}d;
        # Clean specific service logs in workspace
        find /data/openclaw/workspace/Pryan-Fire/hughs-forge/services/*/logs -mtime +{args.log_retention_days} -delete 2>/dev/null || true;
        echo 'Maintenance complete.';
      "
  - id: status_report
    description: "Collect status and verification after maintenance."
    command: |
      echo "## Fleet Maintenance Report"
      echo "Pruned logs and cleared caches across the fleet."
      echo ""
      echo "### Disk Usage Snapshot"
      df -h /data
      echo ""
      echo "### System Uptime"
      uptime
