# Native llama.cpp Setup - Optimized Dual GPU Configuration

Complete guide for setting up natively compiled llama.cpp with optimized multi-GPU support.

**Status**: ✅ Production Ready (as of 2025-12-25)

## Why Native Setup?

Native compilation provides:
- **Direct GPU access** - No containerization overhead
- **Multi-GPU support** - Intel Arc A770 + Nvidia RTX 4070 working together
- **Better performance** - ~493 tok/s prompt processing, ~40 tok/s generation
- **Larger context** - Stable 32K context windows on all models
- **Easier debugging** - Direct access to logs and system tools

## Hardware Requirements

### Verified Configuration
- **Nvidia RTX 4070** (12GB VRAM) - CUDA backend
- **Intel Arc A770** (16GB VRAM) - Vulkan backend
- **GCC 13** or **GCC 12** (CUDA 12.x compatible)
- **CUDA Toolkit 12.x**
- **Vulkan drivers** (Intel and Nvidia)

### Software Prerequisites

```bash
# Check versions
gcc --version        # Should be 13.x or 12.x
nvcc --version       # CUDA 12.x
vulkaninfo --summary # Vulkan support

# Check GPUs
nvidia-smi
lspci | grep -i "VGA.*Intel"
```

## Installation Guide

### Step 1: Install Dependencies (Arch Linux)

```bash
# GCC 13 (CUDA compatible)
sudo pacman -S gcc13

# CUDA toolkit
yay -S cuda

# Vulkan drivers
sudo pacman -S vulkan-intel vulkan-tools

# Build tools
sudo pacman -S cmake git base-devel bc jq
```

### Step 2: Setup Model Storage

```bash
# Create model directory
sudo mkdir -p /data/llama-models
sudo chown -R $(id -u):$(id -g) /data/llama-models

# Verify
ls -la /data/llama-models
```

### Step 3: Build llama.cpp

```bash
# Run setup (checks prerequisites)
make setup

# Build from source (one-time, ~5-10 minutes)
make build

# Install to ~/.local/bin
make install
```

**What the build script does:**
1. Clones llama.cpp to `/tmp/llama.cpp`
2. Detects CUDA-compatible GCC (13 or 12)
3. Configures CMake with CUDA and Vulkan support
4. Compiles `llama-server` binary
5. Copies binary and libraries to `~/.local/bin`

### Step 4: Verify Installation

```bash
# Check if installed
~/.local/bin/llama-server --version

# Should show:
# - CUDA support
# - Vulkan support
# - Version info
```

### Step 5: Start a Model

```bash
# Small model (single GPU, fast)
make use-qwen

# Large model (dual GPU, SOTA)
make use-qwen32b

# Check status
make model-status
```

## Optimized Configuration

### Current Settings (Production Ready)

**Small Models (Single GPU - CUDA):**
- Nemotron Mini 4B: 32K context, CUDA0 only
- Qwen2.5 Coder 7B: 32K context, CUDA0 only
- Backend: CUDA on Nvidia RTX 4070
- Performance: ~80-90 tok/s

**Large Models (Dual GPU - Vulkan):**
- Nemotron Nano 30B: 32K context, 2:1 tensor-split
- Qwen2.5 Coder 32B: 32K context, 2:1 tensor-split
- DeepSeek V2 Lite 16B: 32K context, 2:1 tensor-split
- Backend: Vulkan on Intel Arc + Nvidia RTX
- Tensor Split: 2:1 (67% Intel / 33% Nvidia)
- Performance: ~40 tok/s generation, ~493 tok/s prompt processing

### Why 2:1 Tensor Split?

After testing multiple configurations:

| Split | Intel (16GB) | Nvidia (12GB) | Result |
|-------|-------------|--------------|--------|
| 3:2 | 13.8GB | 9.5GB | ❌ Out of memory at 445 tokens |
| 4:1 | 18.1GB | 6.0GB | ❌ Intel overloaded, won't load |
| **2:1** | **14.7GB** | **8.6GB** | ✅ **Stable, room for compute buffers** |

The 2:1 split leaves ~1.3GB free on Intel and ~3.4GB free on Nvidia for compute operations during inference.

## Configuration Files

### Makefile Variables

```makefile
# Small models - Single GPU CUDA
NEMOTRON_ARGS = --ctx-size 32768 --device CUDA0 --n-gpu-layers -1 --threads 8
QWEN_ARGS = --ctx-size 32768 --device CUDA0 --n-gpu-layers -1 --threads 8

# Large models - Dual GPU Vulkan
NEMOTRON_NANO_ARGS = --ctx-size 32768 --device Vulkan0,Vulkan1 --n-gpu-layers -1 --split-mode layer --tensor-split 2,1 --threads 8
QWEN32B_ARGS = --ctx-size 32768 --device Vulkan0,Vulkan1 --n-gpu-layers -1 --split-mode layer --tensor-split 2,1 --threads 8
DEEPSEEK_ARGS = --ctx-size 32768 --device Vulkan0,Vulkan1 --n-gpu-layers -1 --split-mode layer --tensor-split 2,1 --threads 8
```

### Build Script (build-native.sh)

```bash
#!/bin/bash
set -e

# Add CUDA to PATH
export PATH="/opt/cuda/bin:$PATH"
export LD_LIBRARY_PATH="/opt/cuda/lib64:$LD_LIBRARY_PATH"

# Detect CUDA-compatible GCC
GCC_VERSION=$(gcc -dumpversion | cut -d. -f1)
if [ "$GCC_VERSION" -ge 14 ]; then
    for ver in 13 12; do
        if command -v gcc-$ver &> /dev/null; then
            export CC=gcc-$ver
            export CXX=g++-$ver
            export CUDAHOSTCXX=g++-$ver
            break
        fi
    done
fi

# Build
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_CUDA=ON \
    -DGGML_VULKAN=ON \
    -DLLAMA_CURL=ON

make -j$(nproc) llama-server
```

## Usage Guide

### Starting Models

```bash
# Quick switch between models
make use-qwen           # 7B model (fast)
make use-qwen32b        # 32B model (SOTA)
make use-nemotron-nano  # 30B MoE (balanced)

# Each command:
# 1. Stops current server
# 2. Updates configuration
# 3. Starts new model
# 4. Updates OpenCode config
```

### Monitoring

```bash
# Detailed model status
make model-status

# Shows:
# - Model name and layers
# - Context size (32K)
# - GPU allocation per device
# - Memory usage per GPU
# - KV cache distribution
# - Performance metrics
```

### Testing

```bash
# Quick API test
make test

# Verify setup
make verify

# Check GPU usage
make gpu-check

# View logs
make logs
```

## Troubleshooting

### Build Fails with GCC Error

**Problem:** CUDA 12.x doesn't support GCC 14+

**Solution:**
```bash
# Install GCC 13
sudo pacman -S gcc13

# Verify
gcc-13 --version

# Rebuild
make build
```

### Server Crashes with "Out of Memory"

**Problem:** Tensor split doesn't leave enough room for compute buffers

**Current Solution:** 2:1 tensor-split is optimized and stable

**If still issues:**
1. Try single GPU: `make use-qwen` (smaller model)
2. Reduce context size in Makefile (32K → 24K → 16K)
3. Check other GPU processes: `nvidia-smi`, `intel_gpu_top`

### Vulkan Not Working

**Check Vulkan setup:**
```bash
# List Vulkan devices
vulkaninfo --summary

# Should see both Intel and Nvidia

# Check ICD files
ls /usr/share/vulkan/icd.d/
# Should have: intel_icd.x86_64.json, nvidia_icd.json
```

**Install missing drivers:**
```bash
sudo pacman -S vulkan-intel vulkan-tools
```

### Model Won't Load

**Check logs:**
```bash
make logs
# or
tail -100 /tmp/llama-server.log
```

**Common issues:**
- Model not downloaded (first run takes time)
- Insufficient VRAM (try smaller model)
- Wrong GPU device specified

### Performance Lower Than Expected

**Check GPU usage:**
```bash
# Nvidia
nvidia-smi -l 1

# Intel
intel_gpu_top
```

**Verify layers offloaded:**
```bash
make model-status
# Should show: "Layers: 53/53" (all on GPU)
```

**Check context size:**
```bash
make model-status
# Should show: "Context Size: 32768 tokens"
```

## Performance Benchmarks

### Run Benchmarks

```bash
./benchmark.sh

# Interactive menu:
# 1) Nemotron Mini 4B
# 2) Qwen2.5 Coder 7B
# 3) Nemotron Nano 30B MoE
# 4) Qwen2.5 Coder 32B
# 5) DeepSeek V2 Lite 16B

# Results saved to: /tmp/benchmark_results.json
```

### Current Performance (32K Context)

**Nemotron Nano 30B MoE** (Dual GPU):
- Prompt processing: ~493 tok/s
- Generation: ~40 tok/s
- Stability: ✅ No crashes with 509+ token prompts

**Qwen2.5 Coder 7B** (Single GPU):
- Prompt processing: ~80 tok/s
- Generation: ~80 tok/s
- Best for: Fast iteration, low latency

## Advanced Configuration

### Adjusting Context Size

Edit Makefile:
```makefile
# Reduce if out of memory
NEMOTRON_NANO_ARGS = --ctx-size 24576 ...  # 24K instead of 32K
```

### Adjusting Tensor Split

```makefile
# Try different ratios if needed
--tensor-split 3,2  # 60% Intel, 40% Nvidia
--tensor-split 2,1  # 67% Intel, 33% Nvidia (current, stable)
--tensor-split 1,1  # 50% Intel, 50% Nvidia
```

### Single GPU Mode

Force single GPU (Intel Arc, more VRAM):
```makefile
# Use Vulkan0 only (Intel Arc A770 - 16GB)
QWEN32B_ARGS = --ctx-size 32768 --device Vulkan0 --n-gpu-layers -1 --threads 8
```

## Maintenance

### Updating llama.cpp

```bash
cd /tmp/llama.cpp
git pull
make build
make install
make restart
```

### Cleaning Up

```bash
# Stop service and clean logs
make clean

# Remove build artifacts
rm -rf /tmp/llama.cpp/build

# Remove installed binaries
rm ~/.local/bin/llama-server
rm ~/.local/bin/libggml*.so*
```

### Backup Configuration

```bash
make backup
# Creates timestamped backup in ./backups/
```

## OpenCode Integration

### Install Configuration

```bash
make config-install
```

This installs OpenCode configuration that uses the local llama.cpp server at `localhost:11336`.

**For details, see [OPENCODE_SETUP.md](OPENCODE_SETUP.md)**

## Additional Resources

- **[README.md](README.md)** - Quick start and overview
- **[OPTIMIZED_CONFIG.md](OPTIMIZED_CONFIG.md)** - Configuration details and evolution
- **[VULKAN_ISSUES.md](VULKAN_ISSUES.md)** - Vulkan multi-GPU notes (now stable)
- **[llama.cpp repository](https://github.com/ggml-org/llama.cpp)** - Upstream project

## Important Notes

### llama.cpp Version

This setup requires llama.cpp commit **85c40c9** or later, which includes:
- **PR #18302**: Vulkan multi-GPU command buffer fix (essential for stability)
- Merged: 2025-12-24

Earlier versions will crash on dual GPU setups.

### System Libraries

This setup uses system libraries (no Nix, no Docker):
- Better performance
- Direct GPU access
- Standard library paths
- Easier debugging

### Context Window vs Model Training

Models are trained on larger contexts (1M tokens for Nemotron Nano) but we use 32K because:
- Memory constraints with dual GPU splitting
- 32K is sufficient for most coding tasks
- Can be adjusted up to ~48K if needed (may be unstable)

## Support

For issues:
1. Check this guide's troubleshooting section
2. Run `make model-status` and `make logs`
3. Check [VULKAN_ISSUES.md](VULKAN_ISSUES.md) for known issues
4. Review llama.cpp upstream issues

This is a personal configuration - adapt for your hardware and needs.
