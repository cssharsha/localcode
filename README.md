# OpenCode with Native llama.cpp - Multi-GPU Setup

Local AI development environment using natively compiled llama.cpp with optimized multi-GPU support (Intel Arc + Nvidia RTX).

**Current Status:** ⚠️  3 Working Models (CUDA only) - Vulkan backend broken

**Working Models:** Nemotron Mini 4B (133 tok/s) • Qwen 7B (82 tok/s) • DeepSeek 16B (33 tok/s)

**🐛 Known Issue:** Vulkan backend produces gibberish due to [llama.cpp bug #17106](https://github.com/ggml-org/llama.cpp/issues/17106) affecting Intel Arc A770 + Mesa drivers

## Quick Start

```bash
# First time setup
make setup          # Check prerequisites and create directories
make build          # Build llama.cpp natively (one-time)
make install        # Install to ~/.local/bin
make config-install # Install OpenCode configuration

# Start with your preferred model
make use-qwen       # Fast 7B model (single GPU)
make use-qwen32b    # SOTA 32B model (dual GPU)

# Verify everything is working
make model-status   # Show detailed model configuration
make test           # Test the API
```

## Hardware Configuration

- **Nvidia RTX 4070** (12GB VRAM) - CUDA backend for small models
- **Intel Arc A770** (16GB VRAM) - Vulkan backend for large models
- **Dual GPU Mode**: Vulkan multi-GPU with optimized tensor splitting

## Available Models

### ✅ Working Models (Single GPU - CUDA on Nvidia RTX 4070)
| Model | Parameters | Context | VRAM | Performance | Use Case |
|-------|-----------|---------|------|-------------|----------|
| **Nemotron Mini 4B** | 4B | 32K | ~3GB | 132.65 tok/s | Fast, low latency |
| **Qwen2.5 Coder 7B** | 7B | 32K | ~4.4GB | 82.31 tok/s | **Best for coding** |
| **DeepSeek V2 Lite 16B** | 16B | 32K | ~9GB | 33 tok/s | SOTA reasoning |

### ❌ Models Not Working (Vulkan Bug)
| Model | Issue | Alternative |
|-------|-------|-------------|
| **Nemotron Nano 30B** | [Vulkan bug #17106](https://github.com/ggml-org/llama.cpp/issues/17106) - requires dual GPU | Use Qwen 7B |
| **Qwen2.5 Coder 32B** | Vulkan bug + memory constraints + too large for CUDA | Use Qwen 7B |

**🚨 Critical Issue:** Vulkan backend broken on Intel Arc A770 with Mesa drivers
- **Bug**: llama.cpp issue [#17106](https://github.com/ggml-org/llama.cpp/issues/17106) (open, no fix yet)
- **Impact**: Cannot use dual GPU mode or Intel Arc GPU
- **Workaround**: CUDA-only models (limited to 12GB VRAM)
- **Status**: Monitoring upstream for fix

## Available Make Commands

Run `make help` to see all available commands:

### Setup & Build
```bash
make setup          - Check prerequisites and create directories
make build          - Build llama.cpp from source (native compilation)
make install        - Install llama-server to ~/.local/bin
```

### Service Management
```bash
make start          - Start llama-server with current model
make stop           - Stop llama-server
make restart        - Restart llama-server
make status         - Show service status
make logs           - View llama-server logs
```

### Model Selection

**✅ Working Models (CUDA only):**
```bash
make use-nemotron   - Nemotron Mini 4B (32K context, 133 tok/s)
make use-qwen       - Qwen2.5 Coder 7B (32K context, 82 tok/s) ← RECOMMENDED
make use-deepseek   - DeepSeek V2 Lite 16B (32K context, 33 tok/s)
```

**❌ Broken Models (Vulkan bug):**
```bash
# make use-nemotron-nano  - BROKEN: Vulkan bug #17106
# make use-qwen32b        - BROKEN: Vulkan bug + too large for CUDA
```

### Information & Monitoring
```bash
make current-model  - Show which model is configured/running
make model-status   - Show detailed model load configuration
make model-info     - Show available models
make gpu-check      - Check GPU status
make verify         - Verify the setup is working
make test           - Test the API endpoint
```

### Configuration Management
```bash
make config-install   - Install OpenCode config (using stow)
make config-uninstall - Remove OpenCode config
make config-status    - Check configuration status
make config-edit      - Edit OpenCode configuration
```

### Maintenance
```bash
make backup         - Backup configuration files
make restore        - Restore from backup
make clean          - Stop service and clean logs
```

## Model Status Command

The `make model-status` command provides comprehensive information about the currently loaded model:

```bash
make model-status
```

**Shows:**
- Model name and layer configuration
- Context size and batch settings
- GPU allocation (which GPUs, memory per GPU)
- KV cache distribution
- Memory fit analysis (deficit/surplus)
- Performance metrics (last request)

## Prerequisites

### Required Software
- **GCC 13** or **GCC 12** (CUDA 12.x compatible)
- **CUDA Toolkit 12.x** (for Nvidia GPU support)
- **Vulkan drivers** (for Intel Arc support)
- **CMake, git, build tools**

### Check Prerequisites
```bash
# Check GCC version (need 13 or 12 for CUDA compatibility)
gcc --version

# Check CUDA
nvcc --version
nvidia-smi

# Check Vulkan
vulkaninfo --summary

# Check Intel GPU
lspci | grep -i "VGA.*Intel"
```

### Install Missing Components (Arch Linux)
```bash
# GCC 13 (if needed)
sudo pacman -S gcc13

# CUDA toolkit
yay -S cuda

# Vulkan drivers
sudo pacman -S vulkan-intel vulkan-tools

# Build tools
sudo pacman -S cmake git base-devel
```

## Build Process

The native build uses your system libraries and compiles llama.cpp with both CUDA and Vulkan support:

```bash
# One-time build
make build      # Compiles llama.cpp in /tmp/llama.cpp
make install    # Copies to ~/.local/bin
```

Build script automatically:
- Detects CUDA-compatible GCC version
- Enables both CUDA and Vulkan backends
- Compiles with optimizations
- Uses system libraries (no containerization)

**See [NATIVE_SETUP.md](NATIVE_SETUP.md) for detailed setup instructions.**

## Optimized Configuration

Current configuration is production-ready and stable:

- **Context Size**: 32K tokens (all models)
- **Tensor Split**: 2:1 (67% Intel / 33% Nvidia)
- **Performance**: 40-493 tok/s depending on model and operation
- **Stability**: Tested with 509+ token prompts without crashes

**See [OPTIMIZED_CONFIG.md](OPTIMIZED_CONFIG.md) for configuration details and benchmarks.**

## OpenCode Integration

This setup integrates with OpenCode for AI-assisted development.

### Install Configuration
```bash
make config-install
```

This installs the OpenCode configuration to `~/.config/opencode/` with optimized settings for the llama.cpp models.

**For detailed OpenCode setup and usage, see [OPENCODE_SETUP.md](OPENCODE_SETUP.md).**

## Monitoring & Debugging

### Check Service Status
```bash
make status         # Server status with GPU usage
make model-status   # Detailed model configuration
make logs           # View server logs
```

### Monitor GPUs
```bash
# Nvidia GPU
nvidia-smi -l 1

# Intel GPU
intel_gpu_top

# Or use make command
make gpu-check
```

### Test API
```bash
# Simple test
make test

# Manual test
curl http://localhost:11336/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 50
  }'
```

## Troubleshooting

### Server won't start
```bash
make stop          # Stop any running instance
make logs          # Check for errors
make restart       # Start fresh
```

### GPU not detected
```bash
make gpu-check     # Verify GPUs are visible
nvidia-smi         # Check Nvidia GPU
vulkaninfo         # Check Vulkan support
```

### Out of memory errors
```bash
# Try reducing context size or using single GPU models
make use-qwen      # Smaller model with single GPU
```

### Build fails
```bash
# Check GCC version (needs GCC 13 or 12)
gcc --version

# Check CUDA installation
nvcc --version
```

**For more troubleshooting, see [NATIVE_SETUP.md](NATIVE_SETUP.md#troubleshooting).**

## Docker Alternative (Not Currently Used)

Docker setup is available but not actively maintained. The native setup is recommended for:
- Better performance
- Direct GPU access
- Easier debugging
- No container overhead

If you need Docker setup, see the docker-compose.yml files in the repository, but note they may be outdated.

## Documentation

- **[NATIVE_SETUP.md](NATIVE_SETUP.md)** - Detailed native setup guide
- **[OPTIMIZED_CONFIG.md](OPTIMIZED_CONFIG.md)** - Configuration details and benchmarks
- **[OPENCODE_SETUP.md](OPENCODE_SETUP.md)** - OpenCode integration guide
- **[VULKAN_ISSUES.md](VULKAN_ISSUES.md)** - Vulkan multi-GPU notes (now stable)

## Performance Benchmarks

Run benchmarks on your hardware:
```bash
./benchmark.sh
```

Results are saved to `/tmp/benchmark_results.json`.

**Current performance with Nemotron Nano 30B @ 32K context:**
- Prompt processing: ~493 tok/s
- Generation: ~40 tok/s
- Stability: No crashes with 509+ token prompts

## Contributing

This is a personal development environment configuration. Feel free to adapt for your own use.

## License

See individual component licenses (llama.cpp, model licenses, etc.)
