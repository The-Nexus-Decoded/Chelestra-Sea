name: hughs-forge-deploy
description: "Deploys the hughs-forge trading application to ola-claw-trade."
args:
  service_name:
    description: "Name of the systemd service to restart on ola-claw-trade."
    type: string
    default: hughs-trade-executor.service
  build_command:
    description: "Command to build the hughs-forge project on ola-claw-dev."
    type: string
    default: "echo 'Assuming build is handled by CI or local workflow. Skipping explicit build step here.'"
  artifact_path:
    description: "Path to the deployment artifacts on ola-claw-dev."
    type: string
    default: "/data/openclaw/workspace/Pryan-Fire/hughs-forge/dist"
  remote_deploy_path:
    description: "Remote path on ola-claw-trade where artifacts will be deployed."
    type: string
    default: "/data/openclaw/workspace/Pryan-Fire/hughs-forge"
steps:
  - id: build_local
    description: "Execute build command for hughs-forge on ola-claw-dev."
    command: "{args.build_command}"
  - id: transfer_artifacts
    description: "Transfer built artifacts to ola-claw-trade."
    command: |
      echo "--- Transferring artifacts to ola-claw-trade ---"
      scp -r {args.artifact_path} openclaw@100.104.166.53:{args.remote_deploy_path}
  - id: restart_service
    description: "Restart the hughs-forge service on ola-claw-trade."
    command: |
      echo "--- Restarting {args.service_name} on ola-claw-trade ---"
      ssh openclaw@100.104.166.53 "sudo systemctl restart {args.service_name} && sudo systemctl status {args.service_name} --no-pager"
  - id: verify_deployment
    description: "Verify the deployment by checking service status on ola-claw-trade."
    command: |
      echo "--- Verifying deployment on ola-claw-trade ---"
      ssh openclaw@100.104.166.53 "sudo systemctl is-active {args.service_name}"
