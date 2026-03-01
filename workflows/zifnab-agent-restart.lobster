
name: zifnab-agent-restart
description: "Workflow for securely restarting an OpenClaw agent's gateway on a target server."
args:
  target_host:
    description: "Tailscale IP of the target agent's server (e.g., 100.94.203.10 for Haplo, 100.104.166.53 for Hugh)."
    type: string
  agent_name:
    description: "Name of the agent to restart (e.g., Haplo, Hugh)."
    type: string
  user:
    description: "SSH user for the target server (default: openclaw)."
    type: string
    default: "openclaw"
steps:
  - id: restart_gateway
    description: "Restarting OpenClaw gateway service for {args.agent_name} on {args.target_host}."
    command: 'ssh {args.user}@{args.target_host} "systemctl --user restart openclaw-gateway"'
    timeoutMs: 30000
