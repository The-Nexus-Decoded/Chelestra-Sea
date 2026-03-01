name: patryn-workhorse
description: "Consolidated GitHub orchestration: branch -> commit -> push -> PR -> issue close."
args:
  repo_path:
    description: "Relative path to the repository directory (e.g., Pryan-Fire)."
    type: string
  branch_name:
    description: "Name of the new branch."
    type: string
  commit_message:
    description: "Commit message for the changes."
    type: string
  pr_title:
    description: "Title for the Pull Request."
    type: string
  pr_body:
    description: "Body content for the Pull Request."
    type: string
    default: ""
  issue_ids:
    description: "Comma-separated list of issue IDs to close (e.g., 118,35)."
    type: string
    default: ""
steps:
  - id: validate_state
    description: "Verify repo exists and contains uncommitted changes."
    command: |
      cd /data/openclaw/workspace/{args.repo_path}
      if [ ! -d ".git" ]; then
        echo "Error: Not a git repository."
        exit 1
      fi
      if [ -z "$(git status --porcelain)" ]; then
        echo "Error: No changes to commit."
        exit 1
      fi
      echo "State validated. Changes detected."
  - id: git_ops
    description: "Branch, Add, Commit, and Push."
    command: |
      cd /data/openclaw/workspace/{args.repo_path}
      git checkout -b {args.branch_name}
      git add .
      git commit -m "{args.commit_message}"
      git push -u origin {args.branch_name}
  - id: create_pr
    description: "Create GitHub Pull Request."
    command: |
      gh pr create --repo The-Nexus-Decoded/{args.repo_path} \
        --head {args.branch_name} \
        --title "{args.pr_title}" \
        --body "{args.pr_body}"
    timeoutMs: 60000
  - id: close_issues
    description: "Close associated GitHub issues."
    command: |
      if [ -n "{args.issue_ids}" ]; then
        IFS=',' read -ra ADDR <<< "{args.issue_ids}"
        for id in "${ADDR[@]}"; do
          gh issue close "$id" --repo The-Nexus-Decoded/{args.repo_path} --comment "Closed via Patryn Workhorse pipeline."
        done
      else
        echo "No issues to close."
      fi
  - id: summary
    description: "Final report of orchestration."
    command: |
      echo "## Patryn Workhorse Orchestration Complete"
      echo "- Branch: {args.branch_name}"
      echo "- PR Created: {create_pr.stdout}"
      echo "- Issues Closed: {args.issue_ids}"
