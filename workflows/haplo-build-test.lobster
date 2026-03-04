
name: haplo-build-test
description: "Automated workflow for pulling, installing, building, and testing a project."
args:
  repo_path:
    description: "Relative path to the repository directory (e.g., haplos-workshop/my-project)"
    type: string
  branch:
    description: "Git branch to pull and test from"
    type: string
    default: "main"
steps:
  - id: fetch_code
    description: "Fetching latest code from Git repository."
    command: 'git -C {args.repo_path} pull origin {args.branch}'
    timeoutMs: 60000
  - id: install_dependencies
    description: "Installing project dependencies (assuming npm)."
    command: 'npm install'
    cwd: '{args.repo_path}'
    timeoutMs: 180000 # Allow more time for installs
  - id: build_project
    description: "Building the project."
    command: 'npm run build'
    cwd: '{args.repo_path}'
    timeoutMs: 240000 # Allow more time for builds
  - id: run_unit_tests
    description: "Executing unit tests."
    command: 'npm test'
    cwd: '{args.repo_path}'
    timeoutMs: 300000 # Allow generous time for tests
