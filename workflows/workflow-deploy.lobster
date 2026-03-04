name: workflow-deploy
description: "Deploy Lobster workflows from Chelestra-Sea repository to all fleet servers"
version: "1.0"
args:
  - name: branch
    type: string
    default: "main"
  - name: dry_run
    type: bool
    default: false
steps:
  - id: check_repo
    description: "Verify Chelestra-Sea repository is accessible"
    command: |
      echo "Checking Chelestra-Sea repository access..."
      gh repo view The-Nexus-Decoded/Chelestra-Sea --json name,defaultBranchRef | jq -r '.name + " (" + .defaultBranchRef.name + ")"'
    timeoutMs: 10000

  - id: prepare_workspace
    description: "Create temporary deployment directory"
    command: |
      DEPLOY_DIR="/tmp/workflow-deploy-$(date +%s)"
      mkdir -p "$DEPLOY_DIR/chelestra"
      echo "DEPLOY_DIR=$DEPLOY_DIR"
      echo " Preparing deployment workspace at $DEPLOY_DIR"
    timeoutMs: 5000

  - id: clone_chelestra
    description: "Clone Chelestra-Sea workflows from GitHub"
    command: |
      DEPLOY_DIR="{{steps.prepare_workspace.stdout | grep '^DEPLOY_DIR=' | cut -d= -f2}}"
      cd "$DEPLOY_DIR"
      git clone --depth 1 --branch "{{args.branch}}" https://github.com/The-Nexus-Decoded/Chelestra-Sea.git chelestra
      cd chelestra
      echo "Cloned Chelestra-Sea/{{args.branch}}"
      echo "COMMIT=$(git rev-parse --short HEAD)"
      echo "FILES=$(find workflows -name '*.lobster' | wc -l)"
    timeoutMs: 60000

  - id: list_workflows
    description: "Show workflows that will be deployed"
    command: |
      DEPLOY_DIR="{{steps.prepare_workspace.stdout | grep '^DEPLOY_DIR=' | cut -d= -f2}}"
      echo "=========================================="
      echo "  WORKFLOWS TO DEPLOY (from Chelestra-Sea)"
      echo "=========================================="
      echo ""
      find "$DEPLOY_DIR/chelestra/workflows" -name '*.lobster' -exec basename {} \; | sort
      echo ""
      TOTAL=$(find "$DEPLOY_DIR/chelestra/workflows" -name '*.lobster' | wc -l)
      echo "Total: $TOTAL workflows"
    timeoutMs: 10000

  - id: confirm_deploy
    description: "Approval gate before deploying to fleet"
    command: |
      echo "=========================================="
      echo "  DEPLOYMENT CONFIRMATION"
      echo "=========================================="
      echo ""
      echo "This will copy workflows to ALL fleet servers:"
      echo "  - ola-claw-main (100.103.189.117)"
      echo "  - ola-claw-dev (100.94.203.10)"
      echo "  - ola-claw-trade (100.104.166.53)"
      echo ""
      if [ "{{args.dry_run}}" = "true" ]; then
        echo "[DRY RUN] Would proceed with deployment."
        exit 0
      fi
      echo "Ready to deploy. Approval required."
    approval: required
    timeoutMs: 10000

  - id: deploy_to_main
    description: "Deploy workflows to ola-claw-main (Zifnab)"
    command: |
      DEPLOY_DIR="{{steps.prepare_workspace.stdout | grep '^DEPLOY_DIR=' | cut -d= -f2}}"
      echo ">>> Deploying to ola-claw-main (100.103.189.117)"
      rsync -av --delete "$DEPLOY_DIR/chelestra/workflows/" \
        openclaw@100.103.189.117:/data/openclaw/workspace/workflows/
      echo "Main deployment complete."
    timeoutMs: 60000

  - id: deploy_to_dev
    description: "Deploy workflows to ola-claw-dev (Haplo)"
    command: |
      DEPLOY_DIR="{{steps.prepare_workspace.stdout | grep '^DEPLOY_DIR=' | cut -d= -f2}}"
      echo ">>> Deploying to ola-claw-dev (100.94.203.10)"
      rsync -av --delete "$DEPLOY_DIR/chelestra/workflows/" \
        openclaw@100.94.203.10:/data/openclaw/workspace/workflows/
      echo "Dev deployment complete."
    timeoutMs: 60000

  - id: deploy_to_trade
    description: "Deploy workflows to ola-claw-trade (Hugh)"
    command: |
      DEPLOY_DIR="{{steps.prepare_workspace.stdout | grep '^DEPLOY_DIR=' | cut -d= -f2}}"
      echo ">>> Deploying to ola-claw-trade (100.104.166.53)"
      rsync -av --delete "$DEPLOY_DIR/chelestra/workflows/" \
        openclaw@100.104.166.53:/data/openclaw/workspace/workflows/
      echo "Trade deployment complete."
    timeoutMs: 60000

  - id: verify_deployment
    description: "Verify workflow counts on each server"
    command: |
      echo "=========================================="
      echo "  DEPLOYMENT VERIFICATION"
      echo "=========================================="
      echo ""
      for server in 100.103.189.117 100.94.203.10 100.104.166.53; do
        count=$(ssh openclaw@$server "ls -1 /data/openclaw/workspace/workflows/*.lobster 2>/dev/null | wc -l")
        echo "  $server: $count workflows"
      done
      echo ""
      echo "All servers should have the same count."
    timeoutMs: 30000

  - id: cleanup
    description: "Remove temporary deployment directory"
    command: |
      DEPLOY_DIR="{{steps.prepare_workspace.stdout | grep '^DEPLOY_DIR=' | cut -d= -f2}}"
      rm -rf "$DEPLOY_DIR"
      echo "Cleaned up $DEPLOY_DIR"
    timeoutMs: 5000