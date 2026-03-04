
name: zifnab-github-issue-creation
description: "Workflow for creating a new GitHub issue in a specified repository."
args:
  repo_name:
    description: "Name of the GitHub repository (e.g., Pryan-Fire, Chelestra-Sea)."
    type: string
  title:
    description: "Title of the GitHub issue."
    type: string
  body:
    description: "Body content for the GitHub issue (markdown supported)."
    type: string
    default: ""
  labels:
    description: "Comma-separated labels for the issue (e.g., bug, feature, P1)."
    type: string
    default: "task"
  assignee:
    description: "GitHub username of the assignee (e.g., olalawal, haplo)."
    type: string
steps:
  - id: create_issue
    description: "Creating the GitHub issue."
    command: 'gh issue create --repo The-Nexus-Decoded/{args.repo_name} --title "{args.title}" --body "{args.body}" --label "{args.labels}" --assignee "{args.assignee}"'
    # Note: Requires gh CLI to be configured and authenticated
    timeoutMs: 60000
