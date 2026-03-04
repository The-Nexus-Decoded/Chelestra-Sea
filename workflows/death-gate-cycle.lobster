name: death-gate-cycle
description: "The complete Death Gate Cycle workflow: Sync, Maintenance, Deployment, and Verification."
args:
  log_retention_days:
    description: "Number of days of logs to retain during maintenance."
    type: integer
    default: 7
  hughs_service_name:
    description: "Name of Hugh's systemd service to restart on ola-claw-trade."
    type: string
    default: hughs-trade-executor.service
  hughs_build_command:
    description: "Command to build hughs-forge on ola-claw-dev."
    type: string
    default: "echo 'Assuming build is handled by CI or local workflow. Skipping explicit build step here.'"
  hughs_artifact_path:
    description: "Path to Hugh's deployment artifacts on ola-claw-dev."
    type: string
    default: "/data/openclaw/workspace/Pryan-Fire/hughs-forge/dist"
  hughs_remote_deploy_path:
    description: "Remote path on ola-claw-trade for Hugh's artifacts."
    type: string
    default: "/data/openclaw/workspace/Pryan-Fire/hughs-forge"
steps:
  - id: fleet_sync
    description: "Synchronize all repositories across the fleet."
    command: "/data/openclaw/workspace/Chelestra-Sea/workflows/death-gate-fleet-sync.lobster"
  - id: fleet_maintenance
    description: "Perform automated maintenance across the fleet."
    command: "/data/openclaw/workspace/Chelestra-Sea/workflows/fleet-maintenance-status.lobster --log_retention_days {args.log_retention_days}"
  - id: deploy_hughs_forge
    description: "Deploy Hugh's trading forge to ola-claw-trade."
    command: "/data/openclaw/workspace/Chelestra-Sea/workflows/hughs-forge-deploy.lobster --service_name {args.hughs_service_name} --build_command {args.hughs_build_command} --artifact_path {args.hughs_artifact_path} --remote_deploy_path {args.hughs_remote_deploy_path}"
  - id: final_status_check
    description: "Final health check after the cycle completes."
    command: "/data/openclaw/workspace/Chelestra-Sea/workflows/fleet-status.lobster"
