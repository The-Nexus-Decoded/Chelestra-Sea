
name: haplo-deploy-service
description: "Workflow for deploying a service by restarting its systemd unit on a target server."
args:
  service_name:
    description: "Name of the systemd service to restart (e.g., openclaw-gateway)."
    type: string
  target_host:
    description: "Tailscale IP of the target server (e.g., 100.94.203.10 for Haplo)."
    type: string
  user:
    description: "SSH user for the target server (e.g., openclaw)."
    type: string
    default: "openclaw"
steps:
  - id: restart_service
    description: "Restarting the systemd service on the target host."
    command: 'ssh {args.user}@{args.target_host} "systemctl --user restart {args.service_name}"'
    timeoutMs: 30000
