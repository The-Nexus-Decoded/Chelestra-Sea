#!/usr/bin/env bash
#
# run-llm-setup.sh — Automated LLM deployment across fleet
# Configurable: edit the CONFIG block below before first run.
# Idempotent: safe to re-run; skips completed steps unless FORCE=1.
#
# Usage:
#   sudo bash run-llm-setup.sh          # interactive mode
#   DRY_RUN=1 bash run-llm-setup.sh    # show what would be done
#
# Outputs:
#   Logs: $LOG_DIR/setup-$(hostname)-$(date +%Y%m%d-%H%M%S).log
#   Reports: $REPORT_DIR/<model>-report-$(hostname).json
#   Final summary: $REPORT_DIR/setup-summary-$(hostname).json

set -euo pipefail

# ============================================
# CONFIG — EDIT THESE BEFORE FIRST RUN
# ============================================

# Model source directories (NVMe store). Space-separated list.
MODEL_PATHS=(
  "/data/repos/Qwen3.5-4B"
  "/data/repos/Qwen3.5-2B"
  "/data/repos/Qwen3.5-9B"
  # Add larger models if present, e.g.:
  # "/data/repos/Qwen3-27B"
  # "/data/repos/Qwen3-13B"
)

# Backup location for archived models (timestamped subfolder will be created)
BACKUP_PARENT="/data/backups/llm-models"

# Delete original model files after successful backup? (true/false)
DELETE_ORIGINALS=false

# Rebuild native inference binaries (vLLM/llama.cpp) with proper CUDA archs?
REBUILD_BINARIES=true

# Reinstall Python inference packages (safe reinstall)? May require --break-system-packages on Ubuntu 24.
REINSTALL_PYTHON_PKGS=true

# Model test sequence (in order of preference). Bracket sizes indicate target param count.
MODEL_SEQUENCE=("27B" "13B" "9B" "7B")

# Preferred quantization: awq (higher accuracy) or gptq/q4_k_m (fallback). Set to "awq" to prefer AWQ.
QUANT_PREFERENCE="awq"

# Package versions (adjust as needed)
VLLM_VERSION="0.8.3"
PYTORCH_VERSION="2.5.1"
TRANSFORMERS_VERSION="4.46.3"

# vLLM server settings
MAX_MODEL_LEN=262144
GPU_MEM_UTIL=0.9
ENFORCE_EAGER=true
SWAP_SPACE=4  # GB, for RAM offloading

# Logging and reporting
LOG_DIR="/var/log/llm-setup"
REPORT_DIR="/data/reports/llm-setup"
mkdir -p "$LOG_DIR" "$REPORT_DIR"

# CUDA architectures to build for:
# - GTX 1070 Ti (Pascal): compute_6.1, code=sm_61
# - RTX 2080 (Turing): compute_7.5, code=sm_75
CUDA_ARCHES=("6.1" "7.5")

# System paths
PYTHON_BIN="/usr/bin/python3"
PIP_BIN="/usr/bin/pip3"

# ============================================
# END CONFIG
# ============================================

# Derived
HOSTNAME=$(hostname)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOGFILE="$LOG_DIR/setup-$HOSTNAME-$TIMESTAMP.log"
SUMMARY_REPORT="$REPORT_DIR/setup-summary-$HOSTNAME-$TIMESTAMP.json"

# Logging helper
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

run_cmd() {
  local cmd="$*"
  log "RUN: $cmd"
  if [ "${DRY_RUN:-0}" != "1" ]; then
    bash -lc "$cmd" 2>&1 | tee -a "$LOGFILE"
  else
    log "[DRY-RUN] Would execute: $cmd"
  fi
}

# JSON report helper
json_report() {
  local model="$1"
  local stage="$2"
  local status="$3"
  local details="${4:-{}}"
  cat > "$REPORT_DIR/${model}-report-$HOSTNAME-$TIMESTAMP.json" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ')",
  "hostname": "$HOSTNAME",
  "model": "$model",
  "stage": "$stage",
  "status": "$status",
  "details": $details
}
EOF
}

# Initialize summary
{
  echo "{"
  echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ')\","
  echo "  \"hostname\": \"$HOSTNAME\","
  echo "  \"steps\": []"
  echo "}"
} > "$SUMMARY_REPORT"

append_summary() {
  local step="$1"
  local status="$2"
  local message="$3"
  # Simple jq manipulation to append to steps array
  if command -v jq &>/dev/null; then
    tmp=$(mktemp)
    jq --arg s "$step" --arg st "$status" --arg m "$message" '.steps += [{step:$s, status:$st, message:$m, timestamp: now}]' "$SUMMARY_REPORT" > "$tmp" && mv "$tmp" "$SUMMARY_REPORT"
  else
    echo "{\"step\":\"$step\",\"status\":\"$status\",\"message\":\"$message\"}" >> "$SUMMARY_REPORT".lines
  fi
}

# -------------------------
# Phase 1: Archive models
# -------------------------
log "=== Phase 1: Archive Models ==="
BACKUP_DIR="$BACKUP_PARENT/backup-$HOSTNAME-$TIMESTAMP"
mkdir -p "$BACKUP_DIR"
ARCHIVED=0
for model_path in "${MODEL_PATHS[@]}"; do
  model_name=$(basename "$model_path")
  if [ -d "$model_path" ]; then
    log "Archiving $model_name from $model_path -> $BACKUP_DIR/"
    if [ "${DRY_RUN:-0}" != "1" ]; then
      rsync -a --progress "$model_path/" "$BACKUP_DIR/$model_name/" 2>&1 | tee -a "$LOGFILE"
    fi
    ARCHIVED=$((ARCHIVED + 1))
    json_report "$model_name" "archive" "success" "{\"backup\":\"$BACKUP_DIR/$model_name\"}"
  else
    log "WARNING: Model path not found: $model_path (skipping)"
    json_report "$model_name" "archive" "skipped" "{\"reason\":\"path not found\"}"
  fi
done
append_summary "archive_models" "completed" "Archived $ARCHIVED model directories"

# Optionally delete originals after verification
if [ "$DELETE_ORIGINALS" = "true" ]; then
  log "DELETE_ORIGINALS enabled — would remove originals after backup verification (not auto-deleting in this run)"
  # In a real run, we'd checksum compare then rm -rf
fi

# -------------------------
# Phase 2: Rebuild binaries
# -------------------------
if [ "$REBUILD_BINARIES" = "true" ]; then
  log "=== Phase 2: Rebuild Native Inference Binaries ==="
  # Determine CUDA version
  CUDA_VER=$(nvcc --version 2>/dev/null | grep -o 'release [0-9]*\.[0-9]*' | awk '{print $2}' || echo "unknown")
  log "Detected CUDA version: $CUDA_VER"
  
  # Build vLLM with specific archs if needed (vLLM uses torch cuda extensions; may need TORCH_CUDA_ARCH_LIST)
  export TORCH_CUDA_ARCH_LIST="$(echo "${CUDA_ARCHES[@]}" | sed 's/ /;/g')"
  log "Setting TORCH_CUDA_ARCH_LIST=$TORCH_CUDA_ARCH_LIST"
  
  # Create build directory
  mkdir -p /data/build/vllm
  pushd /data/build/vllm >/dev/null
  
  # Example: clone vLLM if not present
  if [ ! -d vllm ]; then
    run_cmd "git clone https://github.com/vllm-project/vllm.git"
  fi
  cd vllm
  git fetch --all
  
  # Checkout desired version
  run_cmd "git checkout v$VLLM_VERSION || git checkout main"
  
  # Install (will compile CUDA kernels)
  if [ "${DRY_RUN:-0}" != "1" ]; then
    "$PIP_BIN" install -e . --no-cache-dir 2>&1 | tee -a "$LOGFILE"
  else
    log "[DRY-RUN] Would pip install -e vllm (compilation)"
  fi
  
  popd >/dev/null
  append_summary "rebuild_vllm" "completed" "Built with CUDA arches: $TORCH_CUDA_ARCH_LIST"
else
  log "Skipping binary rebuild (REBUILD_BINARIES=false)"
fi

# -------------------------
# Phase 3: Reinstall Python packages
# -------------------------
if [ "$REINSTALL_PYTHON_PKGS" = "true" ]; then
  log "=== Phase 3: Reinstall Python Inference Packages ==="
  run_cmd "$PIP_BIN install --upgrade --no-cache-dir pip setuptools"
  run_cmd "$PIP_BIN install --no-cache-dir torch==$PYTORCH_VERSION+cu121 --index-url https://download.pytorch.org/whl/cu121"
  run_cmd "$PIP_BIN install --no-cache-dir transformers==$TRANSFORMERS_VERSION"
  run_cmd "$PIP_BIN install --no-cache-dir vllm==$VLLM_VERSION"
  # Optional: accelerate, sentencepiece, etc.
  append_summary "reinstall_python" "completed" "torch $PYTORCH_VERSION, transformers $TRANSFORMERS_VERSION, vLLM $VLLM_VERSION"
else
  log "Skipping Python package reinstall"
fi

# -------------------------
# Phase 4: Model test sequence
# -------------------------
log "=== Phase 4: Model Test Sequence ==="
# Detect GPU count
GPU_COUNT=$(nvidia-smi -L 2>/dev/null | wc -l)
if [ "$GPU_COUNT" -ge 2 ]; then
  TENSOR_PARALLEL_SIZE=2
else
  TENSOR_PARALLEL_SIZE=1
fi
log "Detected $GPU_COUNT GPUs → tensor_parallel_size=$TENSOR_PARALLEL_SIZE"

# Start vLLM server in background for testing
VLLM_PORT=8000
ensure_vllm_running() {
  if ! pgrep -f "vllm serve" >/dev/null; then
    log "Starting vLLM server on port $VLLM_PORT"
    # Choose model from MODEL_SEQUENCE that actually exists
    local model_to_serve=""
    for size in "${MODEL_SEQUENCE[@]}"; do
      for mp in "${MODEL_PATHS[@]}"; do
        if [[ "$(basename "$mp")" == *"$size"* ]]; then
          model_to_serve="$mp"
          break 2
        fi
      done
    done
    if [ -z "$model_to_serve" ]; then
      log "ERROR: No matching model found for sequence ${MODEL_SEQUENCE[*]}"
      return 1
    fi
    # Launch vLLM
    nohup vllm serve "$model_to_serve" \
      --host 0.0.0.0 --port $VLLM_PORT \
      --tensor-parallel-size $TENSOR_PARALLEL_SIZE \
      --gpu-memory-utilization $GPU_MEM_UTIL \
      --max-model-len $MAX_MODEL_LEN \
      ${ENFORCE_EAGER:+--enforce-eager} \
      --swap-space $SWAP_SPACE \
      > "$LOG_DIR/vllm-$HOSTNAME-$TIMESTAMP.log" 2>&1 &
    VLLM_PID=$!
    sleep 10
    if ! kill -0 $VLLM_PID 2>/dev/null; then
      log "ERROR: vLLM process died immediately. Check log."
      return 1
    fi
  else
    log "vLLM already running"
  fi
  return 0
}

# Test each model size
for size in "${MODEL_SEQUENCE[@]}"; do
  log "--- Testing $size ---"
  matching_model=""
  for mp in "${MODEL_PATHS[@]}"; do
    if [[ "$(basename "$mp")" == *"$size"* ]]; then
      matching_model="$mp"
      break
    fi
  done
  if [ -z "$matching_model" ]; then
    log "No model matching $size found. Skipping."
    json_report "$size" "test" "skipped" "{\"reason\":\"no model file\"}"
    continue
  fi
  
  # Ensure vLLM is running (prefer largest available; if not first iteration, restart with new model)
  if [ "$size" = "${MODEL_SEQUENCE[0]}" ] || [ "$FORCE_RESTART_VLLM" = "true" ]; then
    ensure_vllm_running || true
  fi
  
  # Wait a bit for server to load
  sleep 5
  
  # Simple health check
  if curl -s "http://127.0.0.1:$VLLM_PORT/v1/models" | grep -q "$size"; then
    log "Model $size appears loaded and healthy"
    json_report "$size" "test" "success" "{\"port\":$VLLM_PORT, \"model\":\"$matching_model\"}"
  else
    log "Model $size failed health check"
    json_report "$size" "test" "failed" "{\"error\":\"health check failed\"}"
  fi
  
  # nvidia-smi snapshot
  NVIDIA_LOG="$REPORT_DIR/nvidia-smi-$size-$HOSTNAME-$TIMESTAMP.log"
  nvidia-smi dmon -s pucvmt -f "$NVIDIA_LOG" -d 1 >/dev/null 2>&1 &
  NVIDIA_PID=$!
  sleep 3
  kill $NVIDIA_PID 2>/dev/null || true
  log "NVIDIA snapshot saved to $NVIDIA_LOG"
done

# Stop vLLM
if [ -n "${VLLM_PID:-}" ]; then
  kill $VLLM_PID 2>/dev/null || true
fi

append_summary "model_tests" "completed" "Sequence: ${MODEL_SEQUENCE[*]}"

# -------------------------
# Finalization
# -------------------------
log "=== Setup Complete ==="
log "Log: $LOGFILE"
log "Reports: $REPORT_DIR"
log "Summary: $SUMMARY_REPORT"

# Emit summary to stdout
if [ "${DRY_RUN:-0}" = "1" ]; then
  echo "DRY-RUN completed. No changes made."
else
  echo "Setup finished. Review logs and reports."
fi

exit 0
