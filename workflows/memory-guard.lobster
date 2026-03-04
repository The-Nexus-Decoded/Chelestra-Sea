name: memory-guard
description: "MEMORY.md shadow-copy backup. Checksums and saves previous versions when changed. Pure bash, no LLM."
steps:
  - id: backup
    description: "Run memory-guard.sh to check and backup MEMORY.md if changed"
    command: |
      bash /data/repos/Nexus-Vaults/scripts/memory-guard.sh
    timeoutMs: 10000
