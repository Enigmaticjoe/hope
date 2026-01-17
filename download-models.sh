#!/usr/bin/env bash
##############################################################################
#  MODEL DOWNLOADER - Brain AI
#  AMD RX 7900 XT | 20GB VRAM | 128GB RAM
#
#  VRAM LIMITS (20GB):
#    - 7B-13B models: FP16 (full precision)
#    - 14B-27B models: Need 4-bit quantization (AWQ/GPTQ)
#    - 70B+ models: TOO LARGE - won't fit!
#
#  This script downloads models compatible with your hardware.
##############################################################################

set -e

VENV="${HOME}/.venv/vllm"
CACHE_DIR="${HOME}/.cache/huggingface/hub"
INSTALL_DIR="${HOME}/brain-ai"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}"
cat << 'BANNER'
  __  __           _      _   ____                      _                 _ 
 |  \/  | ___   __| | ___| | |  _ \  _____      ___ __ | | ___   __ _  __| |
 | |\/| |/ _ \ / _` |/ _ \ | | | | |/ _ \ \ /\ / / '_ \| |/ _ \ / _` |/ _` |
 | |  | | (_) | (_| |  __/ | | |_| | (_) \ V  V /| | | | | (_) | (_| | (_| |
 |_|  |_|\___/ \__,_|\___|_| |____/ \___/ \_/\_/ |_| |_|_|\___/ \__,_|\__,_|
                                                                             
  AMD RX 7900 XT | 20GB VRAM Compatible Models
BANNER
echo -e "${NC}"

#=============================================================================
# VRAM COMPATIBILITY TABLE
#=============================================================================
echo -e "${BOLD}VRAM Requirements (approximate):${NC}"
echo ""
echo "  Model Size    FP16      4-bit AWQ/GPTQ"
echo "  ─────────────────────────────────────────"
echo "  7B            ~14GB     ~4GB"
echo "  12B           ~24GB     ~6GB   ← FP16 too big!"
echo "  13B           ~26GB     ~7GB   ← FP16 too big!"
echo "  27B           ~54GB     ~14GB  ← Needs quantization"
echo "  70B           ~140GB    ~35GB  ← TOO BIG FOR 20GB!"
echo ""
echo -e "${YELLOW}Your GPU: 20GB VRAM${NC}"
echo -e "${YELLOW}Recommendation: Use 4-bit quantized models for 12B+${NC}"
echo ""

#=============================================================================
# MODEL DEFINITIONS - VRAM COMPATIBLE
#=============================================================================
declare -A MODELS=(
    # FITS IN 20GB - Good choices
    ["dolphin-12b"]="cognitivecomputations/dolphin-2.9.3-mistral-nemo-12b"
    ["phi4-abliterated"]="huihui-ai/Phi-4-abliterated"
    ["wizardlm-13b"]="TheBloke/WizardLM-13B-Uncensored-GPTQ"
    ["gemma3-27b-awq"]="huihui-ai/gemma-3-27b-it-abliterated-AWQ"
    
    # SMALLER MODELS - Fast & efficient
    ["qwen2.5-7b"]="Qwen/Qwen2.5-7B-Instruct"
    ["mistral-7b"]="mistralai/Mistral-7B-Instruct-v0.3"
    ["llama3.2-3b"]="meta-llama/Llama-3.2-3B-Instruct"
    
    # HERMES - Good for Home Assistant
    ["hermes-8b"]="NousResearch/Hermes-3-Llama-3.1-8B"
)

# MODELS THAT WON'T FIT (for reference)
declare -A TOO_LARGE=(
    ["hermes-70b"]="NousResearch/Hermes-3-Llama-3.1-70B"
    ["dark-champion-18b"]="DavidAU/Llama-3.2-8X3B-MOE-Dark-Champion-Instruct-uncensored-abliterated-18.4B"
)

#=============================================================================
# SHOW MENU
#=============================================================================
show_menu() {
    echo -e "${BOLD}Available Models (20GB VRAM Compatible):${NC}"
    echo ""
    echo -e "${GREEN}RECOMMENDED FOR YOUR SETUP:${NC}"
    echo "  1) dolphin-12b      - Uncensored, experimental (12B, ~8GB w/4bit)"
    echo "  2) phi4-abliterated - Uncensored Phi-4 (14B, ~9GB w/4bit)"
    echo "  3) wizardlm-13b     - GPTQ quantized, uncensored (13B, ~7GB)"
    echo "  4) gemma3-27b-awq   - AWQ quantized 27B (fits in 20GB!)"
    echo ""
    echo -e "${CYAN}FAST & EFFICIENT:${NC}"
    echo "  5) qwen2.5-7b       - Great all-rounder (7B, ~14GB FP16)"
    echo "  6) mistral-7b       - Fast inference (7B, ~14GB FP16)"
    echo "  7) llama3.2-3b      - Lightning fast (3B, ~6GB FP16)"
    echo "  8) hermes-8b        - Tool calling for Home Assistant (8B)"
    echo ""
    echo -e "${YELLOW}DOWNLOAD OPTIONS:${NC}"
    echo "  a) Download ALL recommended models"
    echo "  o) Download Ollama embedding models"
    echo "  c) Custom HuggingFace model ID"
    echo "  q) Quit"
    echo ""
}

#=============================================================================
# DOWNLOAD FUNCTION
#=============================================================================
download_model() {
    local model_id="$1"
    local model_name="$2"
    
    echo ""
    echo -e "${CYAN}Downloading: ${model_name}${NC}"
    echo "HuggingFace ID: ${model_id}"
    echo ""
    
    # Activate venv
    source "${VENV}/bin/activate"
    
    # Download using huggingface-cli
    huggingface-cli download "${model_id}" --local-dir-use-symlinks False
    
    deactivate
    
    echo -e "${GREEN}✓ Downloaded: ${model_name}${NC}"
}

#=============================================================================
# DOWNLOAD OLLAMA MODELS
#=============================================================================
download_ollama_models() {
    echo ""
    echo -e "${CYAN}Downloading Ollama models for embeddings...${NC}"
    echo ""
    
    # Check if Ollama container is running
    if ! docker ps | grep -q brain_ollama; then
        echo -e "${YELLOW}Ollama container not running. Start it first:${NC}"
        echo "  docker start brain_ollama"
        return 1
    fi
    
    local OLLAMA_MODELS=(
        "nomic-embed-text:latest"
        "llama3.2:latest"
        "qwen2.5-coder:7b"
    )
    
    for model in "${OLLAMA_MODELS[@]}"; do
        echo "Pulling ${model}..."
        docker exec brain_ollama ollama pull "${model}"
    done
    
    echo ""
    echo -e "${GREEN}✓ Ollama models downloaded${NC}"
    docker exec brain_ollama ollama list
}

#=============================================================================
# UPDATE vLLM CONFIG
#=============================================================================
update_vllm_config() {
    local model_id="$1"
    local env_file="${INSTALL_DIR}/.env"
    
    if [[ -f "${env_file}" ]]; then
        # Update VLLM_MODEL in .env
        sed -i "s|^VLLM_MODEL=.*|VLLM_MODEL=${model_id}|" "${env_file}"
        echo -e "${GREEN}Updated ${env_file} with new model${NC}"
        echo ""
        echo "Restart vLLM to use new model:"
        echo "  ${INSTALL_DIR}/vllm-server.sh restart"
    fi
}

#=============================================================================
# MAIN
#=============================================================================
main() {
    while true; do
        show_menu
        read -p "Select option: " choice
        
        case "${choice}" in
            1)
                download_model "${MODELS[dolphin-12b]}" "Dolphin 12B"
                update_vllm_config "${MODELS[dolphin-12b]}"
                ;;
            2)
                download_model "${MODELS[phi4-abliterated]}" "Phi-4 Abliterated"
                update_vllm_config "${MODELS[phi4-abliterated]}"
                ;;
            3)
                download_model "${MODELS[wizardlm-13b]}" "WizardLM 13B GPTQ"
                update_vllm_config "${MODELS[wizardlm-13b]}"
                ;;
            4)
                download_model "${MODELS[gemma3-27b-awq]}" "Gemma3 27B AWQ"
                update_vllm_config "${MODELS[gemma3-27b-awq]}"
                ;;
            5)
                download_model "${MODELS[qwen2.5-7b]}" "Qwen 2.5 7B"
                update_vllm_config "${MODELS[qwen2.5-7b]}"
                ;;
            6)
                download_model "${MODELS[mistral-7b]}" "Mistral 7B"
                update_vllm_config "${MODELS[mistral-7b]}"
                ;;
            7)
                download_model "${MODELS[llama3.2-3b]}" "Llama 3.2 3B"
                update_vllm_config "${MODELS[llama3.2-3b]}"
                ;;
            8)
                download_model "${MODELS[hermes-8b]}" "Hermes 3 8B"
                update_vllm_config "${MODELS[hermes-8b]}"
                ;;
            a|A)
                echo "Downloading all recommended models..."
                download_model "${MODELS[dolphin-12b]}" "Dolphin 12B"
                download_model "${MODELS[phi4-abliterated]}" "Phi-4 Abliterated"
                download_model "${MODELS[hermes-8b]}" "Hermes 3 8B"
                download_model "${MODELS[qwen2.5-7b]}" "Qwen 2.5 7B"
                ;;
            o|O)
                download_ollama_models
                ;;
            c|C)
                echo ""
                read -p "Enter HuggingFace model ID: " custom_model
                if [[ -n "${custom_model}" ]]; then
                    download_model "${custom_model}" "Custom Model"
                    read -p "Set as default vLLM model? [y/N] " -n 1 -r
                    echo
                    [[ $REPLY =~ ^[Yy]$ ]] && update_vllm_config "${custom_model}"
                fi
                ;;
            q|Q)
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
        clear
    done
}

#=============================================================================
# WARNINGS
#=============================================================================
echo -e "${RED}${BOLD}⚠️  IMPORTANT VRAM WARNINGS:${NC}"
echo ""
echo "The following models from your list WON'T FIT in 20GB VRAM:"
echo ""
echo "  ❌ Hermes-3-Llama-3.1-70B (needs ~35GB+ even quantized)"
echo "  ❌ Dark-Champion-18.4B MOE (MOE models need extra VRAM)"
echo ""
echo "I've substituted with compatible alternatives."
echo ""
read -p "Press Enter to continue..."

main
