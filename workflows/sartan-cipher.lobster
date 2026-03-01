name: sartan-cipher
description: "Workspace sync to Nexus-Vaults with change detection - only syncs when files actually changed"
args:
  org:
    description: "GitHub organization"
    type: string
    default: "The-Nexus-Decoded"
  workspace:
    description: "Source workspace path"
    type: string
    default: "/data/openclaw/workspace"
steps:
  - id: check_changes
    description: "Hash workspace files to detect changes"
    command: |
      echo "=== WORKSPACE CHANGE DETECTION ==="
      find ${workspace} -maxdepth 2 -name '*.md' -o -name '*.lobster' -o -name '*.json' -o -name '*.sh' 2>/dev/null | sort | xargs md5sum 2>/dev/null | md5sum | cut -d' ' -f1
    timeoutMs: 15000

  - id: clone_vault
    description: "Clone Nexus-Vaults to temp dir"
    command: |
      rm -rf /tmp/sartan-vault && mkdir -p /tmp/sartan-vault
      gh repo clone ${org}/Nexus-Vaults /tmp/sartan-vault/Nexus-Vaults -- --depth 1 2>&1
      echo "CLONE_OK"
    timeoutMs: 60000

  - id: sync_files
    description: "Copy workspace files to vault (with redaction)"
    command: |
      vault="/tmp/sartan-vault/Nexus-Vaults"
      src="${workspace}"
      mkdir -p "$vault/memory" "$vault/workflows" "$vault/config"
      cp -v "$src"/*.md "$vault/" 2>/dev/null
      cp -v "$src"/memory/*.md "$vault/memory/" 2>/dev/null
      cp -v "$src"/workflows/*.lobster "$vault/workflows/" 2>/dev/null
      # Redact sensitive data
      for f in "$vault"/*.md "$vault"/memory/*.md; do
        [ -f "$f" ] || continue
        sed -i 's/[A-Za-z0-9_-]\{39\}/[REDACTED_KEY]/g' "$f" 2>/dev/null
      done
      echo ""
      cd "$vault" && git add -A && git diff --cached --stat
    timeoutMs: 30000

  - id: review_diff
    description: "Show what will be pushed"
    command: |
      vault="/tmp/sartan-vault/Nexus-Vaults"
      echo "========================================="
      echo "  SARTAN CIPHER - VAULT SYNC"
      echo "========================================="
      echo ""
      cd "$vault" && git diff --cached --stat
      echo ""
      echo "Approve to commit and push to Nexus-Vaults."
    approval: required
    timeoutMs: 10000

  - id: push
    description: "Commit and push to Nexus-Vaults"
    command: |
      vault="/tmp/sartan-vault/Nexus-Vaults"
      cd "$vault"
      hostname=$(hostname)
      git commit -m "sync: workspace snapshot from $hostname ($(date -u '+%Y-%m-%d %H:%M UTC'))" 2>&1
      git push origin main 2>&1
      echo ""
      rm -rf /tmp/sartan-vault
      echo "=== SARTAN CIPHER COMPLETE ==="
    timeoutMs: 60000
