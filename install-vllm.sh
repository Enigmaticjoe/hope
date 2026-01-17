#!/usr/bin/env bash
##############################################################################
#  vLLM BARE METAL INSTALLATION
#  AMD RX 7900 XT (gfx1100 / RDNA3) | 20GB VRAM | ROCm 6.x
#
#  This installs vLLM natively (NOT in Docker) for best RDNA3 compatibility
##############################################################################

set -e

#=============================================================================
# CONFIG
#=============================================================================
VLLM_VENV="${HOME}/.venv/vllm"
INSTALL_DIR="${HOME}/brain-ai"
ROCM_VERSION="6.2"
PYTHON_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}{sys.version_info.minor}')")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "${CYAN}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

#=============================================================================
# AMD RDNA3 ENVIRONMENT - CRITICAL
#=============================================================================
export HSA_OVERRIDE_GFX_VERSION=11.0.0
export HIP_VISIBLE_DEVICES=0
export ROCR_VISIBLE_DEVICES=0
export PYTORCH_HIP_ALLOC_CONF=expandable_segments:True
export VLLM_USE_TRITON_FLASH_ATTN=0

echo -e "${CYAN}"
cat << 'BANNER'
 __   __ _     _     __  __   ___           _        _ _ 
 \ \ / /| |   | |   |  \/  | |_ _|_ __  ___| |_ __ _| | |
  \ V / | |   | |   | |\/| |  | || '_ \/ __| __/ _` | | |
   | |  | |___| |___| |  | |  | || | | \__ \ || (_| | | |
   |_|  |_____|_____|_|  |_| |___|_| |_|___/\__\__,_|_|_|
                                                         
  AMD RX 7900 XT • ROCm 6.x • gfx1100 (RDNA3)
BANNER
echo -e "${NC}"

#=============================================================================
# PREREQUISITES CHECK
#=============================================================================
log "Checking prerequisites..."

# ROCm
if ! command -v rocm-smi &>/dev/null; then
    err "ROCm not installed!\nInstall with: sudo apt install rocm-hip-sdk rocm-libs rocm-smi-lib"
fi
ok "ROCm: $(rocm-smi --version 2>/dev/null | head -1)"

# Python
if ! command -v python3 &>/dev/null; then
    err "Python 3.10+ required"
fi
ok "Python: $(python3 --version)"

# GPU devices
if [[ ! -e /dev/kfd ]] || [[ ! -e /dev/dri ]]; then
    err "GPU devices not found (/dev/kfd, /dev/dri)"
fi
ok "GPU devices present"

# Show GPU
echo ""
log "Detected GPU:"
rocm-smi --showproductname 2>/dev/null | grep -E "GPU|Card" || true
rocm-smi --showmeminfo vram 2>/dev/null | grep -E "Total|Used" | head -4 || true

#=============================================================================
# STOP EXISTING SERVICES
#=============================================================================
log "Stopping any existing vLLM services..."
pkill -f "vllm.entrypoints" 2>/dev/null || true
sleep 2
ok "Existing services stopped"

#=============================================================================
# CLEANUP OLD VENV
#=============================================================================
if [[ -d "${VLLM_VENV}" ]]; then
    warn "Existing vLLM venv found"
    read -p "Remove and reinstall? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "${VLLM_VENV}"
        ok "Removed old venv"
    else
        err "Installation cancelled"
    fi
fi

#=============================================================================
# CREATE DIRECTORIES
#=============================================================================
mkdir -p "${INSTALL_DIR}"
mkdir -p "${HOME}/.cache/huggingface"

#=============================================================================
# CREATE VIRTUAL ENVIRONMENT
#=============================================================================
log "Creating virtual environment at ${VLLM_VENV}..."
python3 -m venv "${VLLM_VENV}"
source "${VLLM_VENV}/bin/activate"

pip install --upgrade pip wheel setuptools

#=============================================================================
# INSTALL PYTORCH FOR ROCm
#=============================================================================
log "Installing PyTorch with ROCm ${ROCM_VERSION}..."

pip install torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/rocm${ROCM_VERSION}

# Verify PyTorch
log "Verifying PyTorch..."
python3 << 'PYCHECK'
import torch
print(f"  PyTorch version: {torch.__version__}")
print(f"  ROCm/HIP available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"  GPU: {torch.cuda.get_device_name(0)}")
    props = torch.cuda.get_device_properties(0)
    print(f"  VRAM: {props.total_memory / 1024**3:.1f} GB")
PYCHECK

#=============================================================================
# INSTALL vLLM
#=============================================================================
log "Installing vLLM..."

# Try prebuilt ROCm wheel first
VLLM_WHEEL_URL="https://github.com/vllm-project/vllm/releases/download/v0.6.6.post1/vllm-0.6.6.post1+rocm62-cp${PYTHON_VER}-cp${PYTHON_VER}-linux_x86_64.whl"

if pip install "${VLLM_WHEEL_URL}" 2>/dev/null; then
    ok "Installed vLLM from ROCm wheel"
else
    warn "Prebuilt wheel not found, installing from pip..."
    pip install vllm
fi

#=============================================================================
# INSTALL EXTRAS
#=============================================================================
log "Installing additional dependencies..."
pip install huggingface_hub accelerate scipy sentencepiece protobuf

#=============================================================================
# VERIFY INSTALLATION
#=============================================================================
log "Verifying vLLM installation..."
python3 << 'VERIFY'
import torch
import vllm
print(f"  vLLM version: {vllm.__version__}")
print(f"  PyTorch version: {torch.__version__}")
print(f"  ROCm available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"  GPU memory: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB")
VERIFY

deactivate

#=============================================================================
# CREATE SERVER WRAPPER SCRIPT
#=============================================================================
WRAPPER="${INSTALL_DIR}/vllm-server.sh"
log "Creating server wrapper: ${WRAPPER}"

cat > "${WRAPPER}" << 'WRAPPER_SCRIPT'
#!/usr/bin/env bash
##############################################################################
#  vLLM Server - AMD RX 7900 XT (gfx1100)
##############################################################################

VENV="${HOME}/.venv/vllm"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
LOG_FILE="${SCRIPT_DIR}/vllm.log"
PID_FILE="${SCRIPT_DIR}/vllm.pid"

# Load config
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"

# AMD RDNA3 Environment - CRITICAL FOR gfx1100
export HSA_OVERRIDE_GFX_VERSION="${HSA_OVERRIDE_GFX_VERSION:-11.0.0}"
export HIP_VISIBLE_DEVICES="${HIP_VISIBLE_DEVICES:-0}"
export ROCR_VISIBLE_DEVICES="${ROCR_VISIBLE_DEVICES:-0}"
export VLLM_USE_TRITON_FLASH_ATTN="${VLLM_USE_TRITON_FLASH_ATTN:-0}"
export PYTORCH_HIP_ALLOC_CONF="${PYTORCH_HIP_ALLOC_CONF:-expandable_segments:True}"

# HuggingFace token for gated models
[[ -n "${HF_TOKEN}" ]] && export HUGGING_FACE_HUB_TOKEN="${HF_TOKEN}"
[[ -n "${HF_TOKEN}" ]] && export HF_TOKEN="${HF_TOKEN}"

# Server defaults
MODEL="${VLLM_MODEL:-cognitivecomputations/dolphin-2.9.3-mistral-nemo-12b}"
PORT="${VLLM_PORT:-8000}"
DTYPE="${VLLM_DTYPE:-float16}"
MAX_MODEL_LEN="${VLLM_MAX_MODEL_LEN:-8192}"
GPU_MEMORY="${VLLM_GPU_MEMORY:-0.90}"
MAX_SEQS="${VLLM_MAX_SEQS:-16}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

start() {
    if [[ -f "${PID_FILE}" ]] && kill -0 "$(cat ${PID_FILE})" 2>/dev/null; then
        echo -e "${RED}vLLM already running (PID: $(cat ${PID_FILE}))${NC}"
        return 1
    fi

    echo -e "${CYAN}Starting vLLM server...${NC}"
    echo "  Model:   ${MODEL}"
    echo "  Port:    ${PORT}"
    echo "  Dtype:   ${DTYPE}"
    echo "  Context: ${MAX_MODEL_LEN}"
    echo "  VRAM:    ${GPU_MEMORY} utilization"
    echo ""

    source "${VENV}/bin/activate"

    nohup python3 -m vllm.entrypoints.openai.api_server \
        --host 0.0.0.0 \
        --port "${PORT}" \
        --model "${MODEL}" \
        --served-model-name "$(basename ${MODEL})" \
        --dtype "${DTYPE}" \
        --max-model-len "${MAX_MODEL_LEN}" \
        --gpu-memory-utilization "${GPU_MEMORY}" \
        --max-num-seqs "${MAX_SEQS}" \
        --trust-remote-code \
        --enforce-eager \
        --disable-log-requests \
        > "${LOG_FILE}" 2>&1 &

    echo $! > "${PID_FILE}"
    echo -e "${GREEN}Started (PID: $!)${NC}"
    echo "Logs: tail -f ${LOG_FILE}"
    echo "API:  http://localhost:${PORT}/v1"
}

stop() {
    if [[ -f "${PID_FILE}" ]]; then
        local PID=$(cat "${PID_FILE}")
        if kill -0 "${PID}" 2>/dev/null; then
            echo "Stopping vLLM (PID: ${PID})..."
            kill "${PID}"
            sleep 3
            kill -9 "${PID}" 2>/dev/null || true
        fi
        rm -f "${PID_FILE}"
    fi
    pkill -f "vllm.entrypoints" 2>/dev/null || true
    echo -e "${GREEN}Stopped${NC}"
}

status() {
    echo "=== vLLM Server Status ==="
    if [[ -f "${PID_FILE}" ]] && kill -0 "$(cat ${PID_FILE})" 2>/dev/null; then
        echo -e "Status: ${GREEN}RUNNING${NC} (PID: $(cat ${PID_FILE}))"
        echo "Model:  ${MODEL}"
        echo "Port:   ${PORT}"
        
        if curl -sf "http://localhost:${PORT}/health" &>/dev/null; then
            echo -e "Health: ${GREEN}OK${NC}"
            echo ""
            echo "Loaded models:"
            curl -sf "http://localhost:${PORT}/v1/models" 2>/dev/null | \
                python3 -c "import sys,json; d=json.load(sys.stdin); print('\n'.join(['  - '+m['id'] for m in d.get('data',[])]))" 2>/dev/null || true
        else
            echo -e "Health: ${CYAN}Starting...${NC}"
        fi
    else
        echo -e "Status: ${RED}STOPPED${NC}"
    fi
    
    echo ""
    echo "=== GPU Status ==="
    rocm-smi --showuse --showmeminfo vram 2>/dev/null | head -15 || true
}

case "${1:-status}" in
    start)   start ;;
    stop)    stop ;;
    restart) stop; sleep 2; start ;;
    status)  status ;;
    logs)    tail -f "${LOG_FILE}" ;;
    *)       echo "Usage: $0 {start|stop|restart|status|logs}"; exit 1 ;;
esac
WRAPPER_SCRIPT

chmod +x "${WRAPPER}"
ok "Created ${WRAPPER}"

#=============================================================================
# CREATE .ENV FILE
#=============================================================================
ENV_FILE="${INSTALL_DIR}/.env"
log "Creating configuration: ${ENV_FILE}"

cat > "${ENV_FILE}" << 'ENVFILE'
#=============================================================================
# vLLM Server Configuration
# Edit this file to change models/settings, then restart vLLM
#=============================================================================

# DEFAULT MODEL - Change this to switch models
# Models must be downloaded first (see download-models.sh)
VLLM_MODEL=cognitivecomputations/dolphin-2.9.3-mistral-nemo-12b

# Server settings
VLLM_PORT=8000
VLLM_DTYPE=float16
VLLM_MAX_MODEL_LEN=8192
VLLM_GPU_MEMORY=0.90
VLLM_MAX_SEQS=16

# HuggingFace token (required for gated models like Llama)
# Get yours at: https://huggingface.co/settings/tokens
# HF_TOKEN=hf_xxxxxxxxxxxxx

# AMD GPU Settings (RDNA3 = gfx1100)
HSA_OVERRIDE_GFX_VERSION=11.0.0
HIP_VISIBLE_DEVICES=0
ROCR_VISIBLE_DEVICES=0
VLLM_USE_TRITON_FLASH_ATTN=0
PYTORCH_HIP_ALLOC_CONF=expandable_segments:True
ENVFILE

ok "Created ${ENV_FILE}"

#=============================================================================
# CREATE SYSTEMD SERVICE
#=============================================================================
SERVICE_FILE="/etc/systemd/system/vllm.service"
log "Creating systemd service..."

sudo tee "${SERVICE_FILE}" > /dev/null << EOF
[Unit]
Description=vLLM OpenAI API Server (AMD ROCm)
After=network.target

[Service]
Type=forking
User=${USER}
Group=${USER}
WorkingDirectory=${INSTALL_DIR}
ExecStart=${WRAPPER} start
ExecStop=${WRAPPER} stop
PIDFile=${INSTALL_DIR}/vllm.pid
Restart=on-failure
RestartSec=15
TimeoutStartSec=600

# AMD RDNA3 GPU
Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"
Environment="HIP_VISIBLE_DEVICES=0"
Environment="ROCR_VISIBLE_DEVICES=0"
Environment="VLLM_USE_TRITON_FLASH_ATTN=0"
Environment="PYTORCH_HIP_ALLOC_CONF=expandable_segments:True"
Environment="HOME=${HOME}"

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
ok "Created systemd service: vllm"

#=============================================================================
# DONE
#=============================================================================
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  vLLM Installation Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. Download models:"
echo "   ${INSTALL_DIR}/download-models.sh"
echo ""
echo "2. Edit configuration:"
echo "   nano ${ENV_FILE}"
echo ""
echo "3. Start vLLM:"
echo "   ${WRAPPER} start"
echo "   # OR"
echo "   sudo systemctl enable --now vllm"
echo ""
echo "4. Check status:"
echo "   ${WRAPPER} status"
echo ""
echo "API Endpoint: http://localhost:8000/v1"
echo ""
