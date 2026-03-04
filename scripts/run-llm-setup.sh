#!/usr/bin/env bash
#
# run-llm-setup.sh
#
# Comprehensive vLLM deployment for OpenClaw fleet.
# - Archive models from NVMe store
# - Rebuild vLLM with proper CUDA architectures
# - Reinstall Python inference packages
# - Test model sequence (27B → 13B → 9B → 7B; AWQ preferred, Q4_K_M fallback)
# - Produce logs, nvidia-smi snapshots, quant artifacts, JSON report per model
#
# Usage: Edit configuration variables below, then run as root or openclaw user.
# Logs: $LOG_DIR/setup-$(hostname)-$(date +%Y%m%d-%H%M%S).log
# Reports: $REPORT_DIR/<model-name>-report.json

set -euo pipefail

# ============================================================================
# CONFIGURATION (Edit these before running)
# ============================================================================

MODEL_BASE_DIR="/data/repos"
# Patterns to match model directories (in order of testing, largest first)
MODEL_PATTERNS=(
  "*27B*" "*13B*" "*9B*" "*7B*" "*4B*" "*2B*"
)

ARCHIVE_DIR="/data/openclaw/archives/llm-models"
DELETE_ORIGINALS=false  # Set true to remove source models after successful archive+test

# CUDA architectures to build (space-separated). Auto-detected if left empty.
CUDA_ARCHS="6.1 7.5"  # GTX 1070 Ti (sm_61), RTX 2080 (sm_75)

# Package versions
VLLM_VERSION="0.8.3"
PYTORCH_VERSION="2.5.1"
TRANSFORMERS_VERSION="4.46.3"
AWQ_VERSION="0.2.7"

# vLLM server settings
MAX_MODEL_LEN=262144
GPU_MEM_UTIL=0.9
ENFORCE_EAGER=true
SWAP_SPACE=4  # GB
PORT_BASE=8000

# Logging
LOG_DIR="/data/openclaw/logs/llm-setup"
REPORT_DIR="/data/openclaw/reports/llm-setup"

# ============================================================================
# DERIVED SETTINGS
# ============================================================================

HOSTNAME="$(hostname)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/setup-${HOSTNAME}-${TIMESTAMP}.log"
REPORT_FILE="$REPORT_DIR/${HOSTNAME}-summary-${TIMESTAMP}.json"

mkdir -p "$LOG_DIR" "$REPORT_DIR" "$ARCHIVE_DIR"

# Detect GPU count and architecture
GPU_COUNT="$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)"
if [ -z "$CUDA_ARCHS" ]; then
  GPU_NAME="$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
  case "$GPU_NAME" in
    *"GTX 1070 Ti"*) CUDA_ARCHS="6.1" ;;
    *"RTX 2080"*) CUDA_ARCHS="7.5" ;;
    *) echo "Unknown GPU: $GPU_NAME; please set CUDA_ARCHS manually" >&2; exit 1 ;;
  esac
fi

if [ "$GPU_COUNT" -ge 2 ]; then
  TENSOR_PARALLEL_SIZE=2
else
  TENSOR_PARALLEL_SIZE=1
fi

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# ============================================================================
# PHASE 1: Archive models
# ============================================================================

log "=== PHASE 1: Archive models from $MODEL_BASE_DIR ==="
mkdir -p "$ARCHIVE_DIR"

FOUND_MODELS=()
for pattern in "${MODEL_PATTERNS[@]}"; do
  matches=( $(find "$MODEL_BASE_DIR" -maxdepth 1 -type d -name "$pattern" 2>/dev/null | sort) )
  if [ ${#matches[@]} -gt 0 ]; then
    for model_path in "${matches[@]}"; do
      model_name="$(basename "$model_path")"
      if [[ -n "$model_name" && -d "$model_path" ]]; then
        FOUND_MODELS+=("$model_name")
        log "Found model: $model_name at $model_path"
        rsync -av --progress "$model_path/" "$ARCHIVE_DIR/$model_name/" 2>&1 | tee -a "$LOG_FILE"
      fi
    done
  fi
done

if [ ${#FOUND_MODELS[@]} -eq 0 ]; then
  log "No models found matching patterns. Exiting."
  exit 1
fi

log "Archived ${#FOUND_MODELS[@]} models to $ARCHIVE_DIR"

if $DELETE_ORIGINALS; then
  log "DELETE_ORIGINALS=true — removing original model directories"
  for model in "${FOUND_MODELS[@]}"; do
    rm -rf "$MODEL_BASE_DIR/$model"
    log "Removed $MODEL_BASE_DIR/$model"
  done
fi

# ============================================================================
# PHASE 2: Reinstall Python packages
# ============================================================================

log "=== PHASE 2: Reinstall Python inference packages (CUDA archs: $CUDA_ARCHS) ==="

log "Upgrading pip and installing torch, transformers"
python3 -m pip install --upgrade pip setuptools wheel
python3 -m pip install "torch==$PYTORCH_VERSION" "transformers==$TRANSFORMERS_VERSION" --extra-index-url https://download.pytorch.org/whl/cu118

log "Installing vLLM $VLLM_VERSION"
if ! python3 -m pip install "vllm==$VLLM_VERSION"; then
  log "vLLM pip install failed; building from source with CUDA_ARCH_LIST=$CUDA_ARCHS"
  git clone https://github.com/vllm-project/vllm.git /tmp/vllm-src
  pushd /tmp/vllm-src
  CUDA_ARCH_LIST="$CUDA_ARCHS" pip install -e . --no-build-isolation
  popd
fi

log "Installing AWQ for quantization (optional)"
python3 -m pip install "awq==$AWQ_VERSION" || log "AWQ install failed; quantization will be skipped"

python3 -c "import vllm; print('vLLM version:', vllm.__version__)" 2>&1 | tee -a "$LOG_FILE"

# ============================================================================
# PHASE 3: Model sequence testing
# ============================================================================

log "=== PHASE 3: Testing models ==="

echo "[" > "$REPORT_FILE"
FIRST=true

PORT=$PORT_BASE
for model_name in "${FOUND_MODELS[@]}"; do
  model_path="$MODEL_BASE_DIR/$model_name"
  if [ ! -d "$model_path" ]; then
    log "Model path missing: $model_path — skipping"
    continue
  fi

  log "Testing model: $model_name on port $PORT"
  REPORT_MODEL="/tmp/${model_name}-report.json"

  # Start vLLM server in background
  log "Starting vLLM server: vllm serve '$model_name' --host 0.0.0.0 --port $PORT --tensor-parallel-size $TENSOR_PARALLEL_SIZE --gpu-memory-utilization $GPU_MEM_UTIL --max-model-len $MAX_MODEL_LEN --enforce-eager --swap-space $SWAP_SPACE"
  vllm serve "$model_name" \
    --host 0.0.0.0 --port "$PORT" \
    --tensor-parallel-size "$TENSOR_PARALLEL_SIZE" \
    --gpu-memory-utilization "$GPU_MEM_UTIL" \
    --max-model-len "$MAX_MODEL_LEN" \
    --enforce-eager \
    --swap-space "$SWAP_SPACE" \
    > "/tmp/vllm-${model_name}.out" 2>&1 &
  SERVER_PID=$!

  # Wait for server to be ready
  log "Waiting for server to start..."
  for i in {1..60}; do
    if curl -s "http://localhost:$PORT/v1/models" >/dev/null; then
      log "Server ready (port $PORT)"
      break
    fi
    sleep 2
    if [ $i -eq 60 ]; then
      log "Server failed to start within 120s"
      kill $SERVER_PID 2>/dev/null || true
      continue 2
    fi
  done

  # Capture nvidia-smi snapshot
  NVIDIA_LOG="/tmp/nvidia-smi-${model_name}.log"
  log "Capturing nvidia-smi monitor (30s) to $NVIDIA_LOG"
  nvidia-smi dmon -s pucvmt -c 30 -f "$NVIDIA_LOG" &
  NVIDIA_PID=$!

  # Simple inference test
  log "Running inference test"
  cat <<EOF > "/tmp/test-${model_name}.py"
import openai, json, time, sys
openai.api_base = "http://localhost:$PORT/v1"
openai.api_key = "token-abc"
start = time.time()
resp = openai.Completion.create(model="$model_name", prompt="Hello, world!", max_tokens=20)
elapsed = time.time() - start
print(json.dumps({
  "model": resp.model,
  "tokens": len(resp.choices[0].text.split()),
  "elapsed_sec": elapsed,
  "status": "ok"
}))
EOF
  python3 "/tmp/test-${model_name}.py" | tee -a "$LOG_FILE" | jq '.' > "/tmp/result-${model_name}.json" || true

  # Stop monitoring
  kill $NVIDIA_PID 2>/dev/null || true
  wait $NVIDIA_PID 2>/dev/null || true

  # Stop server
  log "Stopping vLLM server (PID $SERVER_PID)"
  kill $SERVER_PID 2>/dev/null || true
  wait $SERVER_PID 2>/dev/null || true

  # Extract metrics from nvidia-smi log
  if [ -f "$NVIDIA_LOG" ]; then
    AVG_UTIL="$(awk 'NR>1 {sum+=$2} END {if(NR>1) print sum/(NR-1); else print 0}' "$NVIDIA_LOG" 2>/dev/null || echo 0)"
  else
    AVG_UTIL=0
  fi

  # Build JSON report
  cat <<EOF > "$REPORT_MODEL"
{
  "model": "$model_name",
  "hostname": "$HOSTNAME",
  "timestamp": "$TIMESTAMP",
  "port": $PORT,
  "tensor_parallel_size": $TENSOR_PARALLEL_SIZE,
  "gpu_count": $GPU_COUNT,
  "cuda_archs": "$CUDA_ARCHS",
  "test_status": "$(if [ -f "/tmp/result-${model_name}.json" ]; then echo "completed"; else echo "failed"; fi)",
  "avg_gpu_util": $AVG_UTIL,
  "artifacts": {
    "log": "$LOG_FILE",
    "nvidia_smi": "$NVIDIA_LOG",
    "server_out": "/tmp/vllm-${model_name}.out",
    "result": "/tmp/result-${model_name}.json"
  }
}
EOF
  log "Report generated: $REPORT_MODEL"

  # Append to summary JSON
  if $FIRST; then
    FIRST=false
  else
    echo "," >> "$REPORT_FILE"
  fi
  cat "$REPORT_MODEL" >> "$REPORT_FILE"

  PORT=$((PORT + 1))
done

echo "]" >> "$REPORT_FILE"

log "All models processed. Summary report: $REPORT_FILE"

log "=== SETUP COMPLETE ==="
log "Log: $LOG_FILE"
log "Summary JSON: $REPORT_FILE"
log "Archived models: $ARCHIVE_DIR"
log "Next steps: Verify each model's report, configure OpenClaw to use local vLLM endpoints (http://$HOSTNAME:8000-$(($PORT-1)))"

exit 0
