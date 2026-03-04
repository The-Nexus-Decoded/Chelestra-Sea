name: nexus-bridge
description: "Full PR lifecycle - branch, commit, push, create PR, check CI, merge. Replaces haplo-create-pr."
args:
  repo:
    description: "Repo name (e.g. Pryan-Fire)"
    type: string
  branch:
    description: "New branch name"
    type: string
  title:
    description: "PR title and commit message"
    type: string
  body:
    description: "PR body (markdown)"
    type: string
    default: ""
  base:
    description: "Base branch to merge into"
    type: string
    default: "main"
  repo_path:
    description: "Local path to repo on disk"
    type: string
steps:
  - id: create_branch
    description: "Create and switch to new branch"
    command: |
      cd "${repo_path}" && git checkout -b "${branch}" 2>&1
      echo "Branch ${branch} created"
    timeoutMs: 15000

  - id: stage_changes
    description: "Stage all changes"
    command: |
      cd "${repo_path}" && git add -A 2>&1
      changed=$(git diff --cached --stat | tail -1)
      echo "Staged: $changed"
    timeoutMs: 15000

  - id: commit
    description: "Commit staged changes"
    command: |
      cd "${repo_path}" && git commit -m "${title}" 2>&1
    timeoutMs: 15000

  - id: push
    description: "Push branch to origin"
    command: |
      cd "${repo_path}" && git push -u origin "${branch}" 2>&1
    timeoutMs: 30000

  - id: create_pr
    description: "Create the pull request"
    command: |
      gh pr create --repo The-Nexus-Decoded/${repo} --base "${base}" --head "${branch}" --title "${title}" --body "${body}" 2>&1
    timeoutMs: 30000

  - id: review_pr
    description: "Show PR details before CI check"
    command: |
      echo "========================================="
      echo "  NEXUS BRIDGE - PR CREATED"
      echo "========================================="
      echo ""
      echo "Repo: ${repo}"
      echo "Branch: ${branch} -> ${base}"
      echo "Title: ${title}"
      echo ""
      cat
      echo ""
      echo "Approve to check CI status and proceed to merge."
    stdin: $create_pr.stdout
    approval: required
    timeoutMs: 10000

  - id: check_ci
    description: "Check CI/PR checks status"
    command: |
      echo "Waiting 10s for CI to start..."
      sleep 10
      gh pr checks "${branch}" --repo The-Nexus-Decoded/${repo} 2>&1 || echo "No checks configured or still pending"
    timeoutMs: 60000

  - id: pre_merge
    description: "Show CI results and confirm merge"
    command: |
      echo "========================================="
      echo "  NEXUS BRIDGE - MERGE GATE"
      echo "========================================="
      echo ""
      echo "CI Results:"
      cat
      echo ""
      echo "Approve to squash-merge and delete branch."
    stdin: $check_ci.stdout
    approval: required
    timeoutMs: 10000

  - id: merge
    description: "Squash merge and delete branch"
    command: |
      gh pr merge "${branch}" --repo The-Nexus-Decoded/${repo} --squash --delete-branch 2>&1
      echo ""
      echo "=== NEXUS BRIDGE COMPLETE ==="
    timeoutMs: 30000
