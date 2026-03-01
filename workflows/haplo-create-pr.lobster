
name: haplo-create-pr
description: "Workflow for creating a new branch, committing changes, pushing, and opening a GitHub Pull Request."
args:
  repo_path:
    description: "Relative path to the repository directory."
    type: string
  branch_name:
    description: "Name of the new branch to create."
    type: string
  commit_message:
    description: "Commit message for the changes."
    type: string
  pr_title:
    description: "Title for the Pull Request."
    type: string
  pr_body:
    description: "Body content for the Pull Request (markdown supported)."
    type: string
    default: ""
  base_branch:
    description: "The base branch to open the PR against."
    type: string
    default: "main"
steps:
  - id: create_branch
    description: "Creating a new branch."
    command: 'git -C {args.repo_path} checkout -b {args.branch_name}'
  - id: add_all_changes
    description: "Adding all changes to staging."
    command: 'git -C {args.repo_path} add .'
  - id: commit_changes
    description: "Committing changes."
    command: 'git -C {args.repo_path} commit -m "{args.commit_message}"'
  - id: push_branch
    description: "Pushing the new branch to origin."
    command: 'git -C {args.repo_path} push -u origin {args.branch_name}'
  - id: create_pull_request
    description: "Creating a Pull Request."
    command: 'gh pr create --repo The-Nexus-Decoded/Pryan-Fire --base {args.base_branch} --head {args.branch_name} --title "{args.pr_title}" --body "{args.pr_body}"'
    # Note: Requires gh CLI to be configured and authenticated
    timeoutMs: 60000
