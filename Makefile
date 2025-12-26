.PHONY: help setup build install start stop restart status logs test verify gpu-check model-info backup restore use-nemotron use-qwen use-nemotron-nano use-qwen32b use-deepseek current-model model-status opencode-model config-install config-uninstall config-status config-edit clean

# Directories
LLAMA_SRC = /tmp/llama.cpp
LLAMA_BUILD = $(LLAMA_SRC)/build
LLAMA_BIN = $(LLAMA_BUILD)/bin/llama-server
INSTALL_DIR = ~/.local/bin
MODEL_DIR = /data/llama-models
PID_FILE = /tmp/llama-server.pid
LOG_FILE = /tmp/llama-server.log

# GPU Configuration
export VK_ICD_FILENAMES = /usr/share/vulkan/icd.d/nvidia_icd.json:/usr/share/vulkan/icd.d/intel_icd.x86_64.json

# Model configurations
NEMOTRON_MODEL = $(MODEL_DIR)/bartowski_Nemotron-Mini-4B-Instruct-GGUF_Nemotron-Mini-4B-Instruct-Q4_K_M.gguf
NEMOTRON_ARGS = --ctx-size 32768 --device CUDA0 --n-gpu-layers -1 --threads 8

QWEN_MODEL = $(MODEL_DIR)/bartowski_Qwen2.5-Coder-7B-Instruct-GGUF_Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf
QWEN_ARGS = --ctx-size 32768 --device CUDA0 --n-gpu-layers -1 --threads 8

NEMOTRON_NANO_MODEL = $(MODEL_DIR)/bartowski_nvidia_Nemotron-3-Nano-30B-A3B-GGUF_nvidia_Nemotron-3-Nano-30B-A3B-Q4_K_M.gguf
NEMOTRON_NANO_ARGS = --ctx-size 32768 --device Vulkan0 --n-gpu-layers -1 --threads 8

QWEN32B_MODEL = $(MODEL_DIR)/bartowski_Qwen2.5-Coder-32B-Instruct-GGUF_Qwen2.5-Coder-32B-Instruct-Q4_K_M.gguf
QWEN32B_ARGS = --ctx-size 32768 --batch-size 512 --ubatch-size 256 --device Vulkan0,Vulkan1 --n-gpu-layers -1 --split-mode layer --tensor-split 2,1 --threads 8

DEEPSEEK_MODEL = $(MODEL_DIR)/bartowski_DeepSeek-Coder-V2-Lite-Instruct-GGUF_DeepSeek-Coder-V2-Lite-Instruct-Q4_K_M.gguf
DEEPSEEK_ARGS = --ctx-size 32768 --device CUDA0 --n-gpu-layers -1 --threads 8

# Current model (stored in state file)
STATE_FILE = .current-model
CURRENT_MODEL = $(shell cat $(STATE_FILE) 2>/dev/null || echo "nemotron")

# Default target
help:
	@echo "OpenCode with Native llama.cpp (Nix) - Available commands:"
	@echo ""
	@echo "Setup & Build:"
	@echo "  make setup          - Initial setup (directories, GPU check)"
	@echo "  make build          - Build llama.cpp from source using Nix"
	@echo "  make install        - Install llama-server to ~/.local/bin"
	@echo ""
	@echo "Service Management:"
	@echo "  make start          - Start llama-server with current model"
	@echo "  make stop           - Stop llama-server"
	@echo "  make restart        - Restart llama-server"
	@echo "  make status         - Show service status"
	@echo "  make logs           - View llama-server logs"
	@echo ""
	@echo "Model Selection (Single GPU - Nvidia only):"
	@echo "  make use-nemotron   - Nemotron-Mini-4B (32K context, fast)"
	@echo "  make use-qwen       - Qwen2.5-Coder-7B (32K context, better)"
	@echo ""
	@echo "Model Selection (Dual GPU - Nvidia + Intel Arc):"
	@echo "  make use-nemotron-nano  - Nemotron-3-Nano-30B (32K context, 31 tok/s)"
	@echo ""
	@echo "Model Selection (Single GPU - Nvidia CUDA only):"
	@echo "  make use-deepseek       - DeepSeek-Coder-V2-Lite (32K context, 33 tok/s) [Vulkan incompatible]"
	@echo ""
	@echo "❌ Broken Models:"
	@echo "  # make use-qwen32b      - ❌ BROKEN: Vulkan corruption + memory issues"
	@echo "                            Use 'make use-qwen' (7B) or 'make use-nemotron-nano' instead"
	@echo ""
	@echo "Information:"
	@echo "  make current-model  - Show which model is configured/running"
	@echo "  make model-status   - Show detailed model load configuration"
	@echo "  make opencode-model - Show OpenCode model configuration"
	@echo "  make gpu-check      - Check GPU status"
	@echo "  make model-info     - Show available models"
	@echo ""
	@echo "Testing:"
	@echo "  make verify         - Verify the setup is working"
	@echo "  make test           - Test the API endpoint"
	@echo ""
	@echo "Configuration:"
	@echo "  make config-install   - Install OpenCode config (using stow)"
	@echo "  make config-uninstall - Remove OpenCode config"
	@echo "  make config-status    - Check configuration status"
	@echo "  make config-edit      - Edit OpenCode configuration"
	@echo ""
	@echo "Maintenance:"
	@echo "  make backup         - Backup configuration files"
	@echo "  make restore        - Restore from backup"
	@echo "  make clean          - Stop service and clean logs"

# Initial setup
setup:
	@echo "Setting up directories..."
	@sudo mkdir -p $(MODEL_DIR)
	@sudo chown -R $(shell id -u):$(shell id -g) $(MODEL_DIR)
	@mkdir -p $(INSTALL_DIR)
	@echo "✓ Directories created"
	@echo ""
	@echo "Checking GPUs..."
	@nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv || \
		(echo "Warning: NVIDIA GPU not detected"; exit 1)
	@echo ""
	@lspci | grep -i "VGA.*Intel.*Arc" && echo "✓ Intel Arc GPU detected" || \
		(echo "Warning: Intel Arc GPU not detected"; exit 1)
	@echo ""
	@echo "Checking Vulkan drivers..."
	@test -f /usr/share/vulkan/icd.d/nvidia_icd.json && echo "✓ Nvidia Vulkan ICD found" || \
		(echo "❌ Nvidia Vulkan ICD missing"; exit 1)
	@test -f /usr/share/vulkan/icd.d/intel_icd.x86_64.json && echo "✓ Intel Vulkan ICD found" || \
		(echo "❌ Intel Vulkan ICD missing - run: sudo pacman -S vulkan-intel"; exit 1)
	@echo ""
	@echo "Checking Nix..."
	@command -v nix-shell >/dev/null 2>&1 && echo "✓ Nix installed" || \
		(echo "❌ Nix not installed"; exit 1)
	@echo ""
	@echo "✓ Setup complete!"

# Build llama.cpp from source natively (no Nix)
build:
	@./build-native.sh

# Install to ~/.local/bin
install:
	@if [ ! -f "$(LLAMA_BIN)" ]; then \
		echo "❌ llama-server not built yet"; \
		echo "Run 'make build' first"; \
		exit 1; \
	fi
	@echo "Installing llama-server to $(INSTALL_DIR)..."
	@cp $(LLAMA_BIN) $(INSTALL_DIR)/llama-server
	@echo "Installing shared libraries..."
	@cp -v /tmp/llama.cpp/build/bin/libggml*.so* $(INSTALL_DIR)/ 2>/dev/null || true
	@echo "✓ Installed to $(INSTALL_DIR)/llama-server"
	@echo ""
	@echo "Testing installation..."
	@LD_LIBRARY_PATH=$(INSTALL_DIR):$$LD_LIBRARY_PATH $(INSTALL_DIR)/llama-server --version
	@echo ""
	@echo "Make sure $(INSTALL_DIR) is in your PATH"

# Start llama-server
start:
	@if [ -f "$(PID_FILE)" ] && kill -0 $$(cat $(PID_FILE)) 2>/dev/null; then \
		echo "⚠ llama-server is already running (PID: $$(cat $(PID_FILE)))"; \
		echo "Run 'make stop' first or 'make restart' to restart"; \
		exit 1; \
	fi
	@echo "Starting llama-server with model: $(CURRENT_MODEL)..."
	@$(MAKE) _start-$(CURRENT_MODEL)
	@sleep 3
	@if [ -f "$(PID_FILE)" ] && kill -0 $$(cat $(PID_FILE)) 2>/dev/null; then \
		echo "✓ llama-server started (PID: $$(cat $(PID_FILE)))"; \
		echo "✓ Logs: $(LOG_FILE)"; \
		echo ""; \
		echo "Monitor with: make logs"; \
	else \
		echo "❌ Failed to start llama-server"; \
		echo "Check logs: tail -50 $(LOG_FILE)"; \
		exit 1; \
	fi

_start-nemotron:
	@if [ ! -f "$(NEMOTRON_MODEL)" ]; then \
		echo "Downloading Nemotron model..."; \
		LD_LIBRARY_PATH=$(INSTALL_DIR):$$LD_LIBRARY_PATH LD_LIBRARY_PATH=$(INSTALL_DIR):$$LD_LIBRARY_PATH $(INSTALL_DIR)/llama-server --model $(NEMOTRON_MODEL) --hf-repo bartowski/Nemotron-Mini-4B-Instruct-GGUF --hf-file Nemotron-Mini-4B-Instruct-Q4_K_M.gguf --port 11336 --host 0.0.0.0 $(NEMOTRON_ARGS) > $(LOG_FILE) 2>&1 & echo $$! > $(PID_FILE); \
	else \
		LD_LIBRARY_PATH=$(INSTALL_DIR):$$LD_LIBRARY_PATH LD_LIBRARY_PATH=$(INSTALL_DIR):$$LD_LIBRARY_PATH nohup $(INSTALL_DIR)/llama-server --model $(NEMOTRON_MODEL) --port 11336 --host 0.0.0.0 $(NEMOTRON_ARGS) > $(LOG_FILE) 2>&1 & echo $$! > $(PID_FILE); \
	fi

_start-qwen:
	@if [ ! -f "$(QWEN_MODEL)" ]; then \
		echo "Downloading Qwen model..."; \
		LD_LIBRARY_PATH=$(INSTALL_DIR):$$LD_LIBRARY_PATH $(INSTALL_DIR)/llama-server --model $(QWEN_MODEL) --hf-repo bartowski/Qwen2.5-Coder-7B-Instruct-GGUF --hf-file Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf --port 11336 --host 0.0.0.0 $(QWEN_ARGS) > $(LOG_FILE) 2>&1 & echo $$! > $(PID_FILE); \
	else \
		LD_LIBRARY_PATH=$(INSTALL_DIR):$$LD_LIBRARY_PATH nohup $(INSTALL_DIR)/llama-server --model $(QWEN_MODEL) --port 11336 --host 0.0.0.0 $(QWEN_ARGS) > $(LOG_FILE) 2>&1 & echo $$! > $(PID_FILE); \
	fi

_start-nemotron-nano:
	@if [ ! -f "$(NEMOTRON_NANO_MODEL)" ]; then \
		echo "Downloading Nemotron Nano model..."; \
		LD_LIBRARY_PATH=$(INSTALL_DIR):$$LD_LIBRARY_PATH $(INSTALL_DIR)/llama-server --model $(NEMOTRON_NANO_MODEL) --hf-repo bartowski/nvidia_Nemotron-3-Nano-30B-A3B-GGUF --hf-file nvidia_Nemotron-3-Nano-30B-A3B-Q4_K_M.gguf --port 11336 --host 0.0.0.0 $(NEMOTRON_NANO_ARGS) > $(LOG_FILE) 2>&1 & echo $$! > $(PID_FILE); \
	else \
		LD_LIBRARY_PATH=$(INSTALL_DIR):$$LD_LIBRARY_PATH nohup $(INSTALL_DIR)/llama-server --model $(NEMOTRON_NANO_MODEL) --port 11336 --host 0.0.0.0 $(NEMOTRON_NANO_ARGS) > $(LOG_FILE) 2>&1 & echo $$! > $(PID_FILE); \
	fi

_start-qwen32b:
	@if [ ! -f "$(QWEN32B_MODEL)" ]; then \
		echo "Downloading Qwen 32B model..."; \
		LD_LIBRARY_PATH=$(INSTALL_DIR):$$LD_LIBRARY_PATH $(INSTALL_DIR)/llama-server --model $(QWEN32B_MODEL) --hf-repo bartowski/Qwen2.5-Coder-32B-Instruct-GGUF --hf-file Qwen2.5-Coder-32B-Instruct-Q4_K_M.gguf --port 11336 --host 0.0.0.0 $(QWEN32B_ARGS) > $(LOG_FILE) 2>&1 & echo $$! > $(PID_FILE); \
	else \
		LD_LIBRARY_PATH=$(INSTALL_DIR):$$LD_LIBRARY_PATH nohup $(INSTALL_DIR)/llama-server --model $(QWEN32B_MODEL) --port 11336 --host 0.0.0.0 $(QWEN32B_ARGS) > $(LOG_FILE) 2>&1 & echo $$! > $(PID_FILE); \
	fi

_start-deepseek:
	@if [ ! -f "$(DEEPSEEK_MODEL)" ]; then \
		echo "Downloading DeepSeek model..."; \
		LD_LIBRARY_PATH=$(INSTALL_DIR):$$LD_LIBRARY_PATH $(INSTALL_DIR)/llama-server --model $(DEEPSEEK_MODEL) --hf-repo bartowski/DeepSeek-Coder-V2-Lite-Instruct-GGUF --hf-file DeepSeek-Coder-V2-Lite-Instruct-Q4_K_M.gguf --port 11336 --host 0.0.0.0 $(DEEPSEEK_ARGS) > $(LOG_FILE) 2>&1 & echo $$! > $(PID_FILE); \
	else \
		LD_LIBRARY_PATH=$(INSTALL_DIR):$$LD_LIBRARY_PATH nohup $(INSTALL_DIR)/llama-server --model $(DEEPSEEK_MODEL) --port 11336 --host 0.0.0.0 $(DEEPSEEK_ARGS) > $(LOG_FILE) 2>&1 & echo $$! > $(PID_FILE); \
	fi

# Stop llama-server
stop:
	@if [ -f "$(PID_FILE)" ]; then \
		PID=$$(cat $(PID_FILE)); \
		if kill -0 $$PID 2>/dev/null; then \
			echo "Stopping llama-server (PID: $$PID)..."; \
			kill $$PID; \
			sleep 2; \
			if kill -0 $$PID 2>/dev/null; then \
				echo "Force killing..."; \
				kill -9 $$PID; \
			fi; \
			rm -f $(PID_FILE); \
			echo "✓ llama-server stopped"; \
		else \
			echo "⚠ Process not running, cleaning up PID file"; \
			rm -f $(PID_FILE); \
		fi; \
	else \
		echo "⚠ llama-server is not running (no PID file)"; \
	fi

# Restart
restart: stop start

# Status
status:
	@echo "llama-server Status:"
	@echo ""
	@if [ -f "$(PID_FILE)" ]; then \
		PID=$$(cat $(PID_FILE)); \
		if kill -0 $$PID 2>/dev/null; then \
			echo "  ✓ Running (PID: $$PID)"; \
			echo "  Model: $(CURRENT_MODEL)"; \
			ps -p $$PID -o %cpu,%mem,etime,cmd | tail -1; \
		else \
			echo "  ❌ Not running (stale PID file)"; \
			rm -f $(PID_FILE); \
		fi; \
	else \
		echo "  ❌ Not running"; \
	fi
	@echo ""
	@echo "GPU Status:"
	@nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo "  ⚠ nvidia-smi not available"

# View logs
logs:
	@if [ -f "$(LOG_FILE)" ]; then \
		tail -100 $(LOG_FILE); \
	else \
		echo "No log file found at $(LOG_FILE)"; \
	fi

# Model selection targets
use-nemotron:
	@echo "Switching to Nemotron-Mini-4B-Instruct (Single GPU)..."
	@echo "nemotron" > $(STATE_FILE)
	@echo "✓ Model configured: Nemotron-Mini-4B-Instruct"
	@echo "  Size: 4B parameters (~2.7 GB)"
	@echo "  Context: 32K tokens"
	@echo "  GPU: Single (Nvidia RTX 4070)"
	@echo ""
	@echo "Updating OpenCode configuration..."
	@jq '.model = "llama-cpp/bartowski_Nemotron-Mini-4B-Instruct-GGUF_Nemotron-Mini-4B-Instruct-Q4_K_M.gguf"' ~/.config/opencode/opencode.json > /tmp/opencode.json && mv /tmp/opencode.json ~/.config/opencode/opencode.json
	@echo "✓ OpenCode config updated"
	@echo ""
	@$(MAKE) restart
	@echo ""
	@echo "✓ Switched to Nemotron (Single GPU)!"

use-qwen:
	@echo "Switching to Qwen2.5-Coder-7B-Instruct (Single GPU)..."
	@echo "qwen" > $(STATE_FILE)
	@echo "✓ Model configured: Qwen2.5-Coder-7B-Instruct"
	@echo "  Size: 7B parameters (~4.4 GB)"
	@echo "  Context: 32K tokens"
	@echo "  GPU: Single (Nvidia RTX 4070)"
	@echo ""
	@echo "Updating OpenCode configuration..."
	@jq '.model = "llama-cpp/bartowski_Qwen2.5-Coder-7B-Instruct-GGUF_Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf"' ~/.config/opencode/opencode.json > /tmp/opencode.json && mv /tmp/opencode.json ~/.config/opencode/opencode.json
	@echo "✓ OpenCode config updated"
	@echo ""
	@$(MAKE) restart
	@echo ""
	@echo "✓ Switched to Qwen 7B (Single GPU)!"

use-nemotron-nano:
	@echo "Switching to Nemotron-3-Nano-30B (Dual GPU)..."
	@echo "nemotron-nano" > $(STATE_FILE)
	@echo "✓ Model configured: Nemotron-3-Nano-30B-A3B"
	@echo "  Architecture: MoE (3.2B active, 31.6B total)"
	@echo "  Size: ~2-3 GB (Q4_K_M)"
	@echo "  Context: 32K tokens"
	@echo "  GPUs: Dual (67% Intel Arc + 33% Nvidia RTX)"
	@echo ""
	@echo "Updating OpenCode configuration..."
	@jq '.model = "llama-cpp/bartowski_nvidia_Nemotron-3-Nano-30B-A3B-GGUF_nvidia_Nemotron-3-Nano-30B-A3B-Q4_K_M.gguf"' ~/.config/opencode/opencode.json > /tmp/opencode.json && mv /tmp/opencode.json ~/.config/opencode/opencode.json
	@echo "✓ OpenCode config updated"
	@echo ""
	@$(MAKE) restart
	@echo ""
	@echo "✓ Switched to Nemotron Nano (Dual GPU)!"

use-qwen32b:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "❌ ERROR: Qwen2.5-Coder-32B is NOT WORKING"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "Issues:"
	@echo "  • Vulkan corruption: Produces gibberish output (0000..., 9999...)"
	@echo "  • Memory constraints: Needs ~19.5GB, exceeds Intel Arc 16GB"
	@echo "  • Work group limits: Exceeds Vulkan device limits"
	@echo "  • CUDA incompatible: Too large for 12GB Nvidia RTX 4070"
	@echo ""
	@echo "Alternatives:"
	@echo "  ✓ make use-qwen            - Qwen 7B (82 tok/s, works perfectly)"
	@echo "  ✓ make use-nemotron-nano   - Nemotron Nano 30B (31 tok/s, dual GPU)"
	@echo ""
	@echo "See VULKAN_ISSUES.md for details."
	@echo ""
	@false

use-deepseek:
	@echo "Switching to DeepSeek-Coder-V2-Lite-Instruct (Single GPU - CUDA)..."
	@echo "deepseek" > $(STATE_FILE)
	@echo "✓ Model configured: DeepSeek-Coder-V2-Lite-Instruct (CUDA backend due to Vulkan incompatibility)"
	@echo "  Size: 16B parameters (~9 GB)"
	@echo "  Context: 32K tokens"
	@echo "  GPU: Single (Nvidia RTX 4070 - CUDA)"
	@echo ""
	@echo "Updating OpenCode configuration..."
	@jq '.model = "llama-cpp/bartowski_DeepSeek-Coder-V2-Lite-Instruct-GGUF_DeepSeek-Coder-V2-Lite-Instruct-Q4_K_M.gguf"' ~/.config/opencode/opencode.json > /tmp/opencode.json && mv /tmp/opencode.json ~/.config/opencode/opencode.json
	@echo "✓ OpenCode config updated"
	@echo ""
	@$(MAKE) restart
	@echo ""
	@echo "✓ Switched to DeepSeek (Dual GPU)!"

# Show current model
current-model:
	@echo "Current Model Configuration:"
	@echo ""
	@echo "  Configured: $(CURRENT_MODEL)"
	@echo ""
	@if curl -s http://localhost:11336/v1/models >/dev/null 2>&1; then \
		MODEL=$$(curl -s http://localhost:11336/v1/models | jq -r '.data[0].id // "unknown"'); \
		echo "  ✓ Running: $$MODEL"; \
	else \
		echo "  ⚠ Service not running"; \
	fi

# Detailed model status
model-status:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Model Load Configuration"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@if [ ! -f "$(PID_FILE)" ] || ! kill -0 $$(cat $(PID_FILE)) 2>/dev/null; then \
		echo "❌ Server not running"; \
		echo "   Run 'make start' to start the server"; \
		exit 1; \
	fi
	@echo "Status: ✓ Running (PID: $$(cat $(PID_FILE)))"
	@echo ""
	@echo "━━━ Model Information ━━━"
	@MODEL_NAME=$$(grep "llama_model_loader: loaded meta data" $(LOG_FILE) 2>/dev/null | tail -1 | sed 's/.*from //' | sed 's/ (version.*//' | xargs basename); \
	if [ -n "$$MODEL_NAME" ]; then \
		echo "Model: $$MODEL_NAME"; \
	else \
		echo "Model: $(CURRENT_MODEL)"; \
	fi
	@LAYERS=$$(grep "load_tensors: offloaded" $(LOG_FILE) 2>/dev/null | tail -1 | sed 's/.*offloaded //; s/ layers.*//'); \
	if [ -n "$$LAYERS" ]; then echo "Layers: $$LAYERS"; fi
	@echo ""
	@echo "━━━ Context Configuration ━━━"
	@CTX=$$(grep "llama_context: n_ctx " $(LOG_FILE) 2>/dev/null | tail -1 | awk '{print $$NF}'); \
	if [ -n "$$CTX" ]; then \
		echo "Context Size: $$CTX tokens ($$(echo "scale=1; $$CTX/1024" | bc)K)"; \
	fi
	@BATCH=$$(grep "n_batch " $(LOG_FILE) 2>/dev/null | tail -1 | awk '{print $$NF}'); \
	if [ -n "$$BATCH" ]; then echo "Batch Size: $$BATCH"; fi
	@UBATCH=$$(grep "n_ubatch " $(LOG_FILE) 2>/dev/null | tail -1 | awk '{print $$NF}'); \
	if [ -n "$$UBATCH" ]; then echo "Micro Batch: $$UBATCH"; fi
	@echo ""
	@echo "━━━ GPU Configuration ━━━"
	@VULKAN_COUNT=$$(grep "ggml_vulkan: Found" $(LOG_FILE) 2>/dev/null | tail -1 | awk '{print $$3}'); \
	CUDA_COUNT=$$(grep "ggml_cuda_init: found" $(LOG_FILE) 2>/dev/null | tail -1 | awk '{print $$3}'); \
	if [ -n "$$VULKAN_COUNT" ]; then \
		echo "Vulkan Devices: $$VULKAN_COUNT"; \
		grep "ggml_vulkan:" $(LOG_FILE) 2>/dev/null | grep "^ggml_vulkan: [0-9]" | tail -$$VULKAN_COUNT | while read line; do \
			DEV_NUM=$$(echo "$$line" | awk '{print $$2}'); \
			DEV_NAME=$$(echo "$$line" | sed 's/^[^=]*= //; s/ (.*//'); \
			echo "  Vulkan$$DEV_NUM: $$DEV_NAME"; \
		done; \
	fi; \
	if [ -n "$$CUDA_COUNT" ]; then \
		echo "CUDA Devices: $$CUDA_COUNT"; \
		grep "Device [0-9]:" $(LOG_FILE) 2>/dev/null | grep -v "ggml_vulkan" | tail -$$CUDA_COUNT | while read line; do \
			DEV_NUM=$$(echo "$$line" | sed 's/.*Device //; s/:.*//' | tr -d ' '); \
			DEV_NAME=$$(echo "$$line" | sed 's/.*: //; s/,.*//' | cut -d',' -f1); \
			echo "  CUDA$$DEV_NUM: $$DEV_NAME"; \
		done; \
	fi
	@echo ""
	@echo "━━━ Memory Distribution ━━━"
	@grep "load_tensors:.*model buffer size" $(LOG_FILE) 2>/dev/null | tail -10 | sed 's/load_tensors: */  /' | sed 's/ model buffer size = / → /'
	@echo ""
	@echo "━━━ KV Cache ━━━"
	@grep "llama_kv_cache:.*KV buffer" $(LOG_FILE) 2>/dev/null | tail -10 | sed 's/llama_kv_cache: */  /' | sed 's/ KV buffer size = / → /'
	@TOTAL_KV=$$(grep "llama_kv_cache: size" $(LOG_FILE) 2>/dev/null | tail -1 | sed 's/.*size = *//; s/ (.*//'); \
	if [ -n "$$TOTAL_KV" ]; then echo "  Total KV Cache → $$TOTAL_KV"; fi
	@echo ""
	@echo "━━━ Memory Fit Analysis ━━━"
	@grep "llama_params_fit_impl:.*- Vulkan" $(LOG_FILE) 2>/dev/null | tail -10 | sed 's/llama_params_fit_impl: */  /'
	@grep "llama_params_fit_impl:.*- CUDA" $(LOG_FILE) 2>/dev/null | tail -10 | sed 's/llama_params_fit_impl: */  /'
	@echo ""
	@echo "━━━ Performance (Last Request) ━━━"
	@PROMPT_SPEED=$$(grep "prompt eval time" $(LOG_FILE) 2>/dev/null | tail -1 | sed 's/.*, //; s/ tokens.*//'); \
	if [ -n "$$PROMPT_SPEED" ]; then echo "  Prompt Processing: $$PROMPT_SPEED tok/s"; fi
	@GEN_SPEED=$$(grep "eval time" $(LOG_FILE) 2>/dev/null | grep -v prompt | tail -1 | sed 's/.*, //; s/ tokens.*//'); \
	if [ -n "$$GEN_SPEED" ]; then echo "  Generation: $$GEN_SPEED tok/s"; fi
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# OpenCode model config
opencode-model:
	@echo "OpenCode Model Configuration:"
	@echo ""
	@OPENCODE_MODEL=$$(jq -r '.model // "not set"' ~/.config/opencode/opencode.json 2>/dev/null); \
	if [ "$$OPENCODE_MODEL" = "not set" ] || [ -z "$$OPENCODE_MODEL" ]; then \
		echo "  ❌ No model configured in OpenCode"; \
	else \
		echo "  ✓ Configured model: $$OPENCODE_MODEL"; \
		MODEL_NAME=$$(echo $$OPENCODE_MODEL | sed 's/.*bartowski_//; s/_GGUF.*//; s/_/ /g'); \
		echo "  ℹ Friendly name: $$MODEL_NAME"; \
	fi

# Verify setup
verify:
	@echo "Verifying llama-server..."
	@curl -s http://localhost:11336/v1/models >/dev/null || (echo "❌ llama-server not responding"; exit 1)
	@echo "✓ llama-server is running"
	@echo ""
	@echo "Testing API..."
	@curl -s http://localhost:11336/v1/chat/completions \
		-H "Content-Type: application/json" \
		-d '{"model": "test", "messages": [{"role": "user", "content": "hi"}], "max_tokens": 5}' \
		| jq -r '.choices[0].message.content' >/dev/null && echo "✓ API responding" || echo "⚠ API test failed"

# Test API
test:
	@echo "Testing API endpoint..."
	@curl -s http://localhost:11336/v1/chat/completions \
		-H "Content-Type: application/json" \
		-d '{"model": "test", "messages": [{"role": "user", "content": "Say hello"}], "max_tokens": 50}' \
		| jq '.'

# GPU check
gpu-check:
	@echo "GPU Status:"
	@echo ""
	@echo "=== NVIDIA GPU ==="
	@nvidia-smi
	@echo ""
	@echo "=== Vulkan Devices ==="
	@$(INSTALL_DIR)/llama-server --list-devices 2>/dev/null || echo "llama-server not installed"

# Model info
model-info:
	@echo "Available Models in $(MODEL_DIR):"
	@echo ""
	@ls -lh $(MODEL_DIR)/*.gguf 2>/dev/null || echo "No models downloaded yet"

# Configuration management (same as Docker version)
config-install:
	@echo "Installing OpenCode configuration..."
	@mkdir -p ~/.config
	@if [ -d ~/.config/opencode ] && [ ! -L ~/.config/opencode/opencode.json ]; then \
		echo "⚠ Backing up existing config..."; \
		mv ~/.config/opencode ~/.config/opencode.backup.$$(date +%Y%m%d_%H%M%S); \
	fi
	@cd $(CURDIR) && stow -v -t ~ -d . config 2>&1 | grep -v "^BUG in find_stowed_path" || true
	@echo "✓ OpenCode configuration installed!"

config-uninstall:
	@cd $(CURDIR) && stow -v -D -t ~ -d . config 2>&1 | grep -v "^BUG in find_stowed_path" || true
	@echo "✓ OpenCode configuration uninstalled!"

config-status:
	@echo "OpenCode Configuration Status:"
	@if [ -L ~/.config/opencode/opencode.json ]; then \
		echo "  ✓ Managed by stow"; \
	elif [ -f ~/.config/opencode/opencode.json ]; then \
		echo "  ⚠ Not managed by stow"; \
	else \
		echo "  ❌ Not installed"; \
	fi

config-edit:
	@if [ -n "$$EDITOR" ]; then \
		$$EDITOR config/.config/opencode/opencode.json; \
	else \
		vim config/.config/opencode/opencode.json; \
	fi

# Backup
backup:
	@echo "Backing up configuration..."
	@mkdir -p backups
	@cp shell.nix backups/shell.nix.backup.$$(date +%Y%m%d_%H%M%S)
	@cp router-config.json backups/router-config.json.backup.$$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
	@cp config/.config/opencode/opencode.json backups/opencode.json.backup.$$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
	@cp $(STATE_FILE) backups/current-model.backup.$$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
	@echo "✓ Backup created in ./backups/"

# Restore
restore:
	@echo "Available backups:"
	@ls -lt backups/ | head -10
	@echo ""
	@echo "Restoring most recent backup..."
	@cp $$(ls -t backups/shell.nix.backup.* | head -1) shell.nix
	@echo "✓ Configuration restored!"

# Clean
clean:
	@echo "Stopping service and cleaning up..."
	@$(MAKE) stop
	@rm -f $(LOG_FILE)
	@echo "✓ Clean complete (models preserved)"
