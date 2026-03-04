name: patryn-workhorse
description: "CI pipeline - pull, install, build, test with structured results"
args:
  repo_path:
    description: "Path to repository on disk"
    type: string
  branch:
    description: "Git branch to pull"
    type: string
    default: "main"
steps:
  - id: pull
    description: "Fetch latest code"
    command: |
      cd "${repo_path}" && git pull origin "${branch}" 2>&1
    timeoutMs: 60000
  - id: install
    description: "Install dependencies"
    command: |
      cd "${repo_path}" && npm install 2>&1 | tail -5
    timeoutMs: 180000
  - id: build
    description: "Build project"
    command: |
      cd "${repo_path}" && npm run build 2>&1 | tail -10
    timeoutMs: 240000
  - id: test
    description: "Run tests"
    command: |
      cd "${repo_path}" && npm test 2>&1
      echo ""
      echo "=== PATRYN WORKHORSE COMPLETE ==="
    timeoutMs: 300000
