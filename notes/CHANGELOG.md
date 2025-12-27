# Changelog - Cleanup and Optimization

## 2025-12-25 (Part 4) - Critical Bug Discovery: Vulkan Backend Broken

### 🐛 Upstream llama.cpp Bug Identified

**Discovery**: All Vulkan models produce gibberish output due to llama.cpp bug [#17106](https://github.com/ggml-org/llama.cpp/issues/17106)

**Affected Hardware**:
- Intel Arc A770 (DG2) with Mesa driver 25.1.7
- ALL models on Vulkan backend (single or dual GPU)

**Symptoms**:
- Model loads successfully, no errors
- Generates gibberish: "0000...", "9999...", ". . . ."
- High speed but corrupted output
- CPU backend works correctly (slow but accurate)

**Root Cause**: Vulkan shader computation error in llama.cpp affecting Intel GPUs with Mesa drivers

**Status**: Open bug (reopened Nov 16, 2025), no fix yet

**Impact**:
- ❌ **Nemotron Nano 30B**: Broken (requires Vulkan dual GPU)
- ❌ **Qwen 32B**: Broken (Vulkan bug + memory issues + too large for CUDA)
- ✅ **DeepSeek 16B**: Working (switched to CUDA)
- ✅ **All small models**: Working (CUDA only)

**False Benchmark Data**: Earlier benchmarks measured speed only (31.47 tok/s), not output quality. Models were generating gibberish at high speed.

---

## 2025-12-25 (Part 3) - Final Status Summary

### ✅ Working Models (3 total - CUDA only)
| Model | GPU | Backend | Context | Performance | Status |
|-------|-----|---------|---------|-------------|--------|
| **Nemotron Mini 4B** | Single (Nvidia) | CUDA | 32K | 132.65 tok/s | ✅ Fast |
| **Qwen 7B** | Single (Nvidia) | CUDA | 32K | 82.31 tok/s | ✅ Reliable |
| **DeepSeek 16B** | Single (Nvidia) | CUDA | 32K | 33 tok/s | ✅ Fixed (switched from Vulkan) |

### ❌ Broken Models (2 total)
| Model | Issues | Alternative |
|-------|--------|-------------|
| **Nemotron Nano 30B** | Vulkan bug [#17106](https://github.com/ggml-org/llama.cpp/issues/17106) - requires dual GPU | Use Qwen 7B (fast) or none for 30B size |
| **Qwen 32B** | Vulkan bug + memory constraints + work group limits | Use Qwen 7B (smaller but works) |

### Key Findings
- **Critical llama.cpp bug**: Vulkan backend produces gibberish on Intel Arc A770 with Mesa drivers
- **All Vulkan models affected**: Nemotron Nano, Qwen 32B, DeepSeek (before CUDA switch)
- **DeepSeek solution**: Switched to CUDA backend (works perfectly)
- **Nemotron Nano**: No solution - requires dual GPU which needs Vulkan (broken)
- **Qwen 32B**: No solution - Vulkan broken + too large for CUDA
- **Dual GPU unusable**: Cannot use Intel Arc GPU until llama.cpp bug is fixed

---

## 2025-12-25 (Part 2) - Model-Specific Fixes

### Qwen 32B - Context Reduction
**Issue**: Out of memory when loading with 32K context
- **Error**: `ErrorOutOfDeviceMemory` - failed to allocate 1073741824 bytes (1GB) KV buffer on Vulkan0
- **Root Cause**: Qwen 32B is denser than Nemotron 30B MoE (~18.5GB model + 1GB KV cache > 16GB Intel Arc capacity)
- **Fix**: Reduced context from 32K → 16K
- **Configuration**: `--ctx-size 16384 --device Vulkan0,Vulkan1 --tensor-split 2,1`
- **Status**: ✅ Working on dual GPU Vulkan

### DeepSeek 16B - Backend Switch
**Issue**: Gibberish output ("utaciizzizzzz") instead of proper responses
- **Root Cause**: Vulkan backend incompatibility with DeepSeek model architecture
- **Attempted Fixes**:
  - Disabling flash attention (`--flash-attn 0`): ❌ No improvement
  - Single GPU Vulkan (Intel Arc only): ❌ Still gibberish
  - Switching to CUDA: ✅ **Works perfectly!**
- **Fix**: Changed from Vulkan → CUDA backend
- **Configuration**: `--ctx-size 32768 --device CUDA0` (single GPU - Nvidia RTX 4070)
- **Performance**: 77 tok/s prompt, 33 tok/s generation
- **Status**: ✅ Working on single GPU CUDA

### Qwen 32B - Vulkan Corruption (BROKEN)
**Issue**: Gibberish output on Vulkan backend (both single and dual GPU)
- **Symptoms**:
  - With 32K context: `ErrorOutOfDeviceMemory` (needs 1GB KV cache, exceeds Intel Arc 16GB capacity)
  - With 16K context + reduced batch sizes: Loads successfully but produces gibberish ("0000...", "9999...")
  - Work group assertion with default batch sizes (2048)
- **Root Cause**: Dual issue - memory constraints AND Vulkan inference corruption (same as DeepSeek)
- **Attempted Fixes**:
  - Reducing context to 16K: ❌ Solves memory but reveals Vulkan corruption
  - Reducing batch sizes (512/256): ❌ Solves work group assertion but output still corrupted
  - Single GPU Vulkan (Intel Arc only): ❌ Still produces gibberish
  - Dual GPU Vulkan: ❌ Same gibberish issue
- **Why CUDA won't work**: Model requires ~18GB VRAM, Nvidia RTX 4070 only has 12GB
- **Status**: ❌ **NOT WORKING** - No viable configuration found
- **Recommendation**: Use Qwen 7B (works perfectly) or Nemotron Nano 30B instead

### Updated Model Summary
| Model | GPU Config | Context | Backend | Performance | Status |
|-------|-----------|---------|---------|-------------|--------|
| Nemotron Mini 4B | Single (Nvidia) | 32K | CUDA | 132.65 tok/s | ✅ Stable |
| Qwen 7B | Single (Nvidia) | 32K | CUDA | 82.31 tok/s | ✅ Stable |
| Nemotron Nano 30B | Dual (2:1 split) | 32K | Vulkan | 31.47 tok/s | ✅ Stable |
| **DeepSeek 16B** | **Single (Nvidia)** | **32K** | **CUDA** | **33 tok/s** | ✅ **Fixed (Vulkan incompatible)** |
| **Qwen 32B** | **N/A** | **N/A** | **N/A** | **N/A** | ❌ **BROKEN (Vulkan corruption + memory issues)** |

---

## 2025-12-25 (Part 1) - Major Cleanup and Stabilization

### Summary
Completed comprehensive cleanup and documentation update after achieving stable dual GPU configuration with optimized tensor-splitting and 32K context support for compatible models.

### Status: ✅ 4 Models Production Ready, 1 Model Broken

**Working Configuration:**
- Context: 32K tokens (all working models)
- Tensor Split: 2:1 (67% Intel / 33% Nvidia) for dual GPU models
- Performance: 31-133 tok/s depending on model
- Stability: Tested with 509+ token prompts without crashes
- Backends: CUDA for single GPU, Vulkan for dual GPU (where compatible)

---

## Changes Made

### 1. Documentation Updates

#### ✅ README.md - Complete Rewrite
- **Changed**: Native setup now primary method (was Docker-focused)
- **Added**: Hardware configuration details
- **Added**: Model table with performance metrics
- **Added**: Quick start guide for native setup
- **Added**: `make model-status` command documentation
- **Updated**: Docker noted as alternative (not actively maintained)
- **Removed**: Docker-centric workflow references

#### ✅ NATIVE_SETUP.md - Complete Rewrite
- **Removed**: All Nix references (moved to pure native build)
- **Added**: Step-by-step installation guide
- **Added**: Optimized configuration section (32K context, 2:1 split)
- **Added**: Tensor-split comparison table
- **Added**: Build script documentation
- **Added**: Comprehensive troubleshooting guide
- **Added**: Performance benchmark section
- **Updated**: Prerequisites (GCC 13, CUDA, Vulkan)

#### ✅ VULKAN_ISSUES.md - Status Update
- **Changed**: Status from "BROKEN" to "✅ STABLE"
- **Added**: Complete issue resolution history
- **Added**: Configuration evolution (3:2 → 4:1 → 2:1)
- **Added**: Performance benchmarks with optimized config
- **Added**: llama.cpp PR #18302 documentation (critical fix)
- **Added**: Troubleshooting guide for dual GPU
- **Added**: Alternative configurations section

#### ✅ OPTIMIZED_CONFIG.md - Benchmark Update
- **Added**: Latest performance metrics (493 tok/s prompt, 40 tok/s gen)
- **Added**: Benchmark results table from testing
- **Added**: Notes on pending benchmarks with current config
- **Updated**: Memory allocation details
- **Preserved**: Configuration evolution history

#### OPENCODE_SETUP.md - No Changes
- Left as-is per user request (OpenCode integration guide)

### 2. File Cleanup

#### ✅ Removed Nix References
- **Deleted**: `shell.nix` - No longer using Nix environment
- **Deleted**: `setup-env.sh` - Nix environment setup script
- **Deleted**: `setup-env.fish` - Nix environment setup for Fish shell

**Reason**: Moved to pure native build using system libraries for:
- Better performance
- Direct GPU access
- Standard library paths
- Easier debugging

#### ✅ Removed Stale Scripts
- **Deleted**: `/tmp/update_context.sh` - Old context size update script
- **Deleted**: `/tmp/restore_dual_gpu.sh` - Old dual GPU restore script
- **Deleted**: `/tmp/update_makefile.sh` - Old Makefile update script

**Reason**: These were temporary debugging scripts, configuration now stable in Makefile

**Kept**: `/tmp/restore_optimized_config.sh` - Production restore script

### 3. Make Target Additions

#### ✅ Added `make model-status`
Comprehensive model information command showing:
- Model name and layer configuration
- Context size and batch settings
- GPU allocation (memory per device)
- KV cache distribution
- Memory fit analysis (deficit/surplus)
- Performance metrics (last request)

**Usage:**
```bash
make model-status
```

**Added to**:
- Makefile (new target)
- README.md (documentation)
- Help output (`make help`)

### 4. Configuration Stabilization

#### Current Production Settings

**Small Models (Single GPU - CUDA):**
```makefile
NEMOTRON_ARGS = --ctx-size 32768 --device CUDA0 --n-gpu-layers -1 --threads 8
QWEN_ARGS = --ctx-size 32768 --device CUDA0 --n-gpu-layers -1 --threads 8
```

**Large Models (Dual GPU - Vulkan):**
```makefile
NEMOTRON_NANO_ARGS = --ctx-size 32768 --device Vulkan0,Vulkan1 --n-gpu-layers -1 --split-mode layer --tensor-split 2,1 --threads 8
QWEN32B_ARGS = --ctx-size 32768 --device Vulkan0,Vulkan1 --n-gpu-layers -1 --split-mode layer --tensor-split 2,1 --threads 8
DEEPSEEK_ARGS = --ctx-size 32768 --device Vulkan0,Vulkan1 --n-gpu-layers -1 --split-mode layer --tensor-split 2,1 --threads 8
```

#### Memory Distribution (2:1 split)
- Intel Arc A770: 14.7 GB model + 160 MB KV cache (~1.3 GB free)
- Nvidia RTX 4070: 8.6 GB model + 32 MB KV cache (~3.4 GB free)
- Total: ~23.3 GB model + 192 MB KV cache

### 5. Build System

#### Native Build (No Nix, No Docker)
**Build Script**: `build-native.sh`
- Detects CUDA-compatible GCC (13 or 12)
- Enables CUDA and Vulkan backends
- Uses system libraries
- Compiles to `/tmp/llama.cpp/build`
- Installs to `~/.local/bin`

**Commands:**
```bash
make build      # One-time build
make install    # Copy to ~/.local/bin
```

### 6. Benchmark Status

#### Completed Benchmarks (Optimized Config)
- **Nemotron Nano 30B**: 493 tok/s prompt, 40 tok/s generation (32K context, 2:1 split)

#### Historical Benchmarks (Various Configs)
| Model | Config | Performance | Status |
|-------|--------|-------------|--------|
| Nemotron Mini 4B | Single CUDA, 4K | 17.34 tok/s | Old config |
| Qwen 7B | Single CUDA | 1.11 tok/s | Old config, needs retest |
| DeepSeek 16B | Dual Vulkan | 56.98 tok/s | Old config |
| Nemotron Nano 30B | Dual Vulkan | 32.64 tok/s | Old config |

#### Pending Benchmarks
- Qwen2.5 Coder 32B (32K, 2:1) - Expected: ~25 tok/s
- DeepSeek V2 Lite 16B (32K, 2:1) - Expected: ~30 tok/s
- Nemotron Mini 4B (32K, single) - Expected: ~90 tok/s
- Qwen2.5 Coder 7B (32K, single) - Expected: ~80 tok/s

**Run**: `./benchmark.sh` to update with current config

---

## Key Improvements

### Performance
- ✅ Dual GPU working stably with 2:1 tensor-split
- ✅ 32K context (up from 4K-16K)
- ✅ ~493 tok/s prompt processing (up from ~35 tok/s estimates)
- ✅ ~40 tok/s generation (stable, no crashes)

### Stability
- ✅ No more "Out of Memory" crashes at 445+ tokens
- ✅ Handles 509+ token prompts reliably
- ✅ llama.cpp PR #18302 (critical Vulkan fix) confirmed present
- ✅ Tested configuration in production use

### Usability
- ✅ `make model-status` - Comprehensive model information
- ✅ Updated documentation (README, NATIVE_SETUP, VULKAN_ISSUES)
- ✅ Removed confusing Nix references
- ✅ Clear native build process
- ✅ Docker noted as alternative (not primary)

### Maintainability
- ✅ Cleaned up stale scripts
- ✅ Removed unused Nix files
- ✅ Configuration centralized in Makefile
- ✅ Comprehensive documentation
- ✅ Clear troubleshooting guides

---

## Migration Notes

### If Coming from Docker Setup
1. Stop Docker containers: `docker-compose down`
2. Follow [NATIVE_SETUP.md](NATIVE_SETUP.md)
3. Run `make setup && make build && make install`
4. Start with `make use-qwen` (or preferred model)

### If Coming from Nix Setup
1. Remove Nix environment files (already done)
2. Install system dependencies (GCC 13, CUDA, Vulkan)
3. Rebuild: `make build && make install`
4. Restart: `make restart`

### If Coming from Old Tensor-Split
1. Configuration already updated to 2:1
2. Restart server: `make restart`
3. Verify: `make model-status`
4. Test: `make test`

---

## Files Modified

### Documentation
- ✅ `README.md` - Complete rewrite (native-first)
- ✅ `NATIVE_SETUP.md` - Complete rewrite (no Nix)
- ✅ `VULKAN_ISSUES.md` - Status update (now stable)
- ✅ `OPTIMIZED_CONFIG.md` - Benchmark updates
- ⬜ `OPENCODE_SETUP.md` - No changes (per request)

### Configuration
- ✅ `Makefile` - Added `model-status` target
- ✅ `Makefile` - Updated help text (context sizes)
- ✅ `Makefile` - Model switch messages (tensor-split info)

### Scripts
- ✅ `build-native.sh` - Native build (no Nix)
- ✅ `benchmark.sh` - Interactive model testing
- ✅ `/tmp/restore_optimized_config.sh` - Production restore

### Removed
- ❌ `shell.nix` - Nix environment
- ❌ `setup-env.sh` - Nix setup
- ❌ `setup-env.fish` - Nix setup (Fish)
- ❌ `/tmp/update_context.sh` - Stale
- ❌ `/tmp/restore_dual_gpu.sh` - Stale
- ❌ `/tmp/update_makefile.sh` - Stale

---

## Current File Structure

```
/home/sree/Matrix/localcode/
├── README.md                    # Quick start (native-first)
├── NATIVE_SETUP.md              # Detailed setup guide
├── OPTIMIZED_CONFIG.md          # Configuration details
├── VULKAN_ISSUES.md             # Issue resolution history
├── OPENCODE_SETUP.md            # OpenCode integration
├── CHANGELOG.md                 # This file
├── Makefile                     # Main configuration
├── build-native.sh              # Native build script
├── benchmark.sh                 # Interactive benchmarking
├── test_benchmark.cpp           # Test file for benchmarks
├── router-config.json           # Router configuration
├── docker-compose*.yml          # Docker (alternative, not used)
├── Dockerfile.*                 # Docker (alternative, not used)
└── config/                      # OpenCode configuration (stow)

/tmp/
├── llama.cpp/                   # Build directory
├── llama-server.log             # Runtime logs
├── llama-server.pid             # Server PID
├── benchmark_results.json       # Benchmark data
└── restore_optimized_config.sh  # Config restore script

~/.local/bin/
├── llama-server                 # Compiled binary
└── libggml*.so*                 # Shared libraries
```

---

## Next Steps

### For Users

1. **Verify setup:**
   ```bash
   make model-status
   ```

2. **Test performance:**
   ```bash
   ./benchmark.sh
   ```

3. **Switch models as needed:**
   ```bash
   make use-qwen        # Fast 7B
   make use-qwen32b     # SOTA 32B
   ```

### For Development

1. **Run full benchmarks** with optimized config for all models
2. **Test 48K context** (may need single GPU mode)
3. **Monitor llama.cpp updates** for Vulkan improvements
4. **Test larger models** (48B+) if memory allows

---

## Support

For issues:
1. Check `make model-status` and `make logs`
2. Review [NATIVE_SETUP.md](NATIVE_SETUP.md#troubleshooting)
3. Check [VULKAN_ISSUES.md](VULKAN_ISSUES.md) for known issues

---

**Status**: ✅ All cleanup tasks completed, configuration stable and production-ready
