name: workspace-sync
description: Automates the synchronization of OpenClaw agent workspace files to Nexus-Vaults, with critical redaction.
args:
  repo_name:
    default: "The-Nexus-Decoded/Nexus-Vaults"
  source_workspace_path:
    default: "/data/openclaw/workspace/"
  redaction_script_path:
    default: "/data/openclaw/scripts/redact-and-sync.sh"
steps:
  - id: create_temp_dir
    command: mktemp -d
  - id: clone_repo
    command: 'gh repo clone {{args.repo_name}} {{steps.create_temp_dir.stdout}}/{{args.repo_name | basename}}'
    cwd: '{{steps.create_temp_dir.stdout}}'
  - id: copy_md_files
    command: 'cp -v {{args.source_workspace_path}}/*.md {{steps.create_temp_dir.stdout}}/{{args.repo_name | basename}}/'
    cwd: '{{steps.create_temp_dir.stdout}}/{{args.repo_name | basename}}'
  - id: ensure_memory_dir
    command: 'mkdir -p {{steps.create_temp_dir.stdout}}/{{args.repo_name | basename}}/memory/'
    cwd: '{{steps.create_temp_dir.stdout}}/{{args.repo_name | basename}}'
  - id: copy_memory_files
    command: 'cp -v {{args.source_workspace_path}}/memory/*.md {{steps.create_temp_dir.stdout}}/{{args.repo_name | basename}}/memory/'
    cwd: '{{steps.create_temp_dir.stdout}}/{{args.repo_name | basename}}'
  - id: ensure_workflows_dir
    command: 'mkdir -p {{steps.create_temp_dir.stdout}}/{{args.repo_name | basename}}/workflows/'
    cwd: '{{steps.create_temp_dir.stdout}}/{{args.repo_name | basename}}'
  - id: copy_workflow_files
    command: 'cp -v {{args.source_workspace_path}}/workflows/*.lobster {{steps.create_temp_dir.stdout}}/{{args.repo_name | basename}}/workflows/'
    cwd: '{{steps.create_temp_dir.stdout}}/{{args.repo_name | basename}}'
  - id: run_redaction_script
    command: '{{args.redaction_script_path}} {{steps.create_temp_dir.stdout}}/{{args.repo_name | basename}}/'
    cwd: '{{steps.create_temp_dir.stdout}}/{{args.repo_name | basename}}'
  - id: git_add_commit
    command: 'git add . && git commit -m "Automated workspace sync: $(date +''%Y-%m-%d %H:%M:%S'')" || true'
    cwd: '{{steps.create_temp_dir.stdout}}/{{args.repo_name | basename}}'
  - id: git_push
    command: 'git push origin main'
    cwd: '{{steps.create_temp_dir.stdout}}/{{args.repo_name | basename}}'
  - id: cleanup_temp_dir
    command: 'rm -rf {{steps.create_temp_dir.stdout}}'
