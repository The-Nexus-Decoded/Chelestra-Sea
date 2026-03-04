#!/usr/bin/env bash
#
# run-llm-setup.sh
#
# Deployment and testing of vLLM with Qwen models across fleet.
# Spec:
# - Scan NVMe model directory for 4B/2B/9B model files and common quant artifacts
# - Archive matching models to timestamped backup (dry-run mode)
# - Optionally delete originals after archive (only when dry-run disabled)
# - Rebuild native inference binaries with CUDA archs 61 (GTX 1070 Ti) and 75 (RTX 2080)
# - Reinstall Python inference packages (vLLM, transformers, safetensors)
# - Test model sequence: 27B → 13B → 9B → 7B (AWQ preferred, Q4_K_M fallback)
# - For each model: smoke test vLLM server, capture nvidia-smi, produce JSON report
# - All logs and reports saved under /data/openclaw/

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

NVME_PATH="/data/repos"                      # NVMe model storage to scan
MODELS=(
  "Qwen3.5-27B-AWQ"
  "Qwen3.5-13B-AWQ"
  "Qwen3.5-9B-AWQ"
  "Qwen3.5-7B-AWQ"
  "Qwen3.5-4B"
  "Qwen3.5-2B"
)

CALIBRATION_JSONL="/data/openclaw/calib/calib.jsonl"

WORKDIR="/data/openclaw/models"
VENV_DIR="/home/openclaw/.venvs/llm"
PYTHON_BIN="python3"
VLLM_ENTRY="python -m vllm.entrypoints.server"

CUDA_ARCHS="61 75"
REBUILD_LLAMA_CPP=false
REINSTALL_PY_PACKAGES=true

ARCHIVE_DIR="/data/openclaw/archives/llm-models"
LOG_DIR="/data/openclaw/logs/llm-setup"
REPORT_DIR="/data/openclaw/reports/llm-setup"

EXECUTE_DELETIONS=false   # dry-run if false; set true to actually delete originals after archive

# vLLM server
MAX_MODEL_LEN=262144
GPU_MEM_UTIL=0.9
ENFORCE_EAGER=true
SWAP_SPACE=4
PORT_BASE=8000

# ============================================================================
# SETUP
# ============================================================================

HOSTNAME="$(hostname)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/setup-${HOSTNAME}-${TIMESTAMP}.log"
SUMMARY_REPORT="$REPORT_DIR/${HOSTNAME}-summary-${TIMESTAMP}.json"

mkdir -p "$LOG_DIR" "$REPORT_DIR" "$ARCHIVE_DIR" "$WORKDIR"/{raw,quant,logs,reports}

GPU_COUNT="$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)"
TENSOR_PARALLEL_SIZE="$([ "$GPU_COUNT" -ge 2 ] && echo 2 || echo 1)"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
fail() { log "ERROR: $*"; exit 1; }

# Pre-run checks
log "=== PRE-RUN CHECKS ==="
command -v nvidia-smi >/dev/null || fail "nvidia-smi not found"
nvidia-smi --query-gpu=name --format=csv,noheader | grep -q . || fail "No GPUs visible"
if [ ! -f "$CALIBRATION_JSONL" ]; then
  log "Warning: Calibration file not found at $CALIBRATION_JSONL; quantization may fail."
fi
if [ ! -d "$VENV_DIR" ]; then
  log "Creating venv at $VENV_DIR"
  $PYTHON_BIN -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate" || fail "Failed to activate venv"

# ============================================================================
# PHASE 1: Archive models
# ============================================================================

log "=== PHASE 1: Archive models from $NVME_PATH ==="

CANDIDATES=()
for model in "${MODELS[@]}"; do
  [ -d "$NVME_PATH/$model" ] && CANDIDATES+=("$model")
done
[ ${#CANDIDATES[@]} -gt 0 ] || fail "No models found in $NVME_PATH matching MODELS list."

BACKUP_TIMESTAMP="backup_${TIMESTAMP}"
BACKUP_ROOT="$ARCHIVE_DIR/$BACKUP_TIMESTAMP"
mkdir -p "$BACKUP_ROOT"

log "Archiving ${#CANDIDATES[@]} models to $BACKUP_ROOT (dry-run: $([ "$EXECUTE_DELETIONS" = false ] && echo true || echo false))"

ARCHIVE_SUMMARY="$BACKUP_ROOT/summary.json"
echo "[" > "$ARCHIVE_SUMMARY"
FIRST_ARCHIVE=true

for model in "${CANDIDATES[@]}"; do
  SRC="$NVME_PATH/$model"
  DST="$BACKUP_ROOT/$model"
  log "Archiving: $SRC -> $DST"
  mkdir -p "$DST"
  if ! rsync -av --progress "$SRC/" "$DST/" 2>&1 | tee -a "$LOG_FILE"; then
    log "Archive failed for $model; continuing"
    continue
  fi
  SIZE_GB="$(du -sm "$DST" | cut -f1)"
  if ! $FIRST_ARCHIVE; then echo "," >> "$ARCHIVE_SUMMARY"; fi
  FIRST_ARCHIVE=false
  cat >> "$ARCHIVE_SUMMARY" <<EOS
{
  "model": "$model",
  "source": "$SRC",
  "destination": "$DST",
  "size_gb": $SIZE_GB,
  "archived_at": "$TIMESTAMP"
}
EOS
  if $EXECUTE_DELETIONS; then
    log "EXECUTE_DELETIONS=true — removing original: $SRC"
    rm -rf "$SRC"
  fi
done
echo "]" >> "$ARCHIVE_SUMMARY"
log "Archive summary: $ARCHIVE_SUMMARY"

# ============================================================================
# PHASE 2: Reinstall Python packages
# ============================================================================

log "=== PHASE 2: Reinstall Python packages ==="

if $REINSTALL_PY_PACKAGES; then
  log "Upgrading pip and installing torch, transformers"
  $PYTHON_BIN -m pip install --upgrade pip setuptools wheel
  $PYTHON_BIN -m pip install "torch==2.5.1" "transformers==4.46.3" --extra-index-url https://download.pytorch.org/whl/cu118

  log "Installing vLLM 0.8.3"
  if ! $PYTHON_BIN -m pip install "vllm==0.8.3"; then
    log "vLLM pip install failed; building from source with CUDA_ARCH_LIST=$CUDA_ARCHS"
    git clone https://github.com/vllm-project/vllm.git /tmp/vllm-src
    pushd /tmp/vllm-src
    CUDA_ARCH_LIST="$CUDA_ARCHS" $PYTHON_BIN -m pip install -e . --no-build-isolation
    popd
  fi
  $PYTHON_BIN -c "import vllm; print('vLLM version:', vllm.__version__)" 2>&1 | tee -a "$LOG_FILE"
else
  log "REINSTALL_PY_PACKAGES=false — skipping package installation"
fi

# ============================================================================
# PHASE 3: Model testing (AWQ preferred, Q4_K_M fallback if needed)
# ============================================================================

log "=== PHASE 3: Model smoke tests ==="

echo "[" > "$SUMMARY_REPORT"
FIRST_REPORT=true
PORT=$PORT_BASE

for model in "${MODELS[@]}"; do
  MODEL_PATH="$NVME_PATH/$model"
  [ -d "$MODEL_PATH" ] || { log "Missing: $MODEL_PATH — skipping"; continue; }

  log "Testing: $model on port $PORT"
  REPORT_MODEL="$REPORT_DIR/$(echo "$model" | tr '/' '_')-report.json"
  QUANT_MODE="none"
  SERVER_LOG="/tmp/vllm-${model//\//_}.out"

  # If model already AWQ quantized, use directly; else try AWQ quantization then fallback
  if [[ "$model" == *AWQ* ]]; then
    QUANT_MODE="awq"
  else
    if [ -f "$CALIBRATION_JSONL" ] && $PYTHON_BIN -c "import awq" 2>/dev/null; then
      QUANT_PATH="$WORKDIR/quant/$(basename "$model")-awq.gguf"
      mkdir -p "$(dirname "$QUANT_PATH")"
      log "Attempting AWQ quantization -> $QUANT_PATH"
      if $PYTHON_BIN -m awq_quantize --model "$MODEL_PATH" --calib "$CALIBRATION_JSONL" --out "$QUANT_PATH" 2>&1 | tee -a "$LOG_FILE"; then
        QUANT_MODE="awq"
      else
        log "AWQ quantization failed; will try fallback conversion"
      fi
    fi
    if [ "$QUANT_MODE" != "awq" ]; then
      QUANT_MODE="fallback"
      QUANT_PATH="$WORKDIR/quant/$(basename "$model")-q4_k_m.gguf"
      mkdir -p "$(dirname "$QUANT_PATH")"
      log "Fallback: converting to Q4_K_M -> $QUANT_PATH"
      if $PYTHON_BIN "$CONVERT_SCRIPT" --input "$MODEL_PATH" --output "$QUANT_PATH" --quant q4_k_m 2>&1 | tee -a "$LOG_FILE"; then
        QUANT_MODE="q4_k_m"
      else
        QUANT_MODE="failed"
      fi
    fi
  fi

  MODEL_TO_SERVE="$([ "$QUANT_MODE" != "none" ] && echo "$QUANT_PATH" || echo "$MODEL_PATH")"

  # Start vLLM
  log "Starting vLLM: $VLLM_ENTRY serve $MODEL_TO_SERVE --port $PORT --tensor-parallel-size $TENSOR_PARALLEL_SIZE"
  $VLLM_ENTRY serve "$MODEL_TO_SERVE" \
    --host 0.0.0.0 --port "$PORT" \
    --tensor-parallel-size "$TENSOR_PARALLEL_SIZE" \
    --gpu-memory-utilization "$GPU_MEM_UTIL" \
    --max-model-len "$MAX_MODEL_LEN" \
    --enforce-eager \
    --swap-space "$SWAP_SPACE" \
    > "$SERVER_LOG" 2>&1 &
  SERVER_PID=$!

  # Wait
  READY=0
  for i in {1..60}; do
    if curl -s "http://localhost:$PORT/v1/models" >/dev/null; then READY=1; break; fi
    sleep 2
  done
  if [ $READY -ne 1 ]; then
    log "Server failed to start (PID $SERVER_PID)"
    kill $SERVER_PID 2>/dev/null || true
    TEST_STATUS="failed_to_start"
    AVG_UTIL=0
  else
    log "Server ready on port $PORT"
    TEST_STATUS="completed"

    # nvidia-smi monitor
    NVIDIA_LOG="$WORKDIR/logs/nvidia-${model//\//_}.log"
    nvidia-smi dmon -s pucvmt -c 30 -f "$NVIDIA_LOG" &
    NVIDIA_PID=$!

    # Inference test
    TEST_PY="/tmp/test_${model//\//_}.py"
    cat > "$TEST_PY" <<PY
import openai, json, time, sys
openai.api_base = "http://localhost:$PORT/v1"
openai.api_key = "token"
start = time.time()
try:
  resp = openai.Completion.create(model="$(basename "$model")", prompt="Hello", max_tokens=10)
  elapsed = time.time() - start
  print(json.dumps({"status":"ok","tokens":len(resp.choices[0].text.split()),"elapsed_sec":elapsed}))
except Exception as e:
  print(json.dumps({"status":"error","error":str(e)}))
PY
    python3 "$TEST_PY" | tee -a "$LOG_FILE" | jq '.' > "/tmp/result_${model//\//_}.json" || true

    # Stop monitoring
    kill $NVIDIA_PID 2>/dev/null || true
    wait $NVIDIA_PID 2>/dev/null || true

    # Metrics
    AVG_UTIL=0
    if [ -f "$NVIDIA_LOG" ]; then
      AVG_UTIL="$(awk 'NR>1 {sum+=$2} END {if(NR>1) print sum/(NR-1); else print 0}' "$NVIDIA_LOG" 2>/dev/null || echo 0)"
    fi

    # Stop server
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
  fi

  # Report
  cat <<EOS > "$REPORT_MODEL"
{
  "model": "$model",
  "hostname": "$HOSTNAME",
  "timestamp": "$TIMESTAMP",
  "port": $PORT,
  "tensor_parallel_size": $TENSOR_PARALLEL_SIZE,
  "gpu_count": $GPU_COUNT,
  "cuda_archs": "$CUDA_ARCHS",
  "test_status": "$TEST_STATUS",
  "quant_mode": "$QUANT_MODE",
  "avg_gpu_util": $AVG_UTIL,
  "artifacts": {
    "server_log": "$SERVER_LOG",
    "nvidia_smi": "$NVIDIA_LOG",
    "result": "/tmp/result_${model//\//_}.json"
  }
}
EOS
  log "Report generated: $REPORT_MODEL"

  if $FIRST_REPORT; then FIRST_REPORT=false; else echo "," >> "$SUMMARY_REPORT"; fi
  cat "$REPORT_MODEL" >> "$SUMMARY_REPORT"

  PORT=$((PORT + 1))
done

echo "]" >> "$SUMMARY_REPORT"

log "=== SETUP COMPLETE ==="
log "Summary: $SUMMARY_REPORT"
log "Archive: $ARCHIVE_SUMMARY"
log "Logs: $LOG_FILE"

exit 0
