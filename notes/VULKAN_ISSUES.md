# Vulkan Dual GPU - Issue Resolution

## Status: ✅ STABLE (as of 2025-12-25)

**Update:** Dual GPU mode is now working reliably after configuration optimization and llama.cpp PR #18302.

## Hardware Configuration
- **GPU 1**: Intel Arc A770 (16GB VRAM) - Vulkan backend
- **GPU 2**: Nvidia RTX 4070 (12GB VRAM) - CUDA + Vulkan backends
- **Total**: 28GB VRAM available
- **llama.cpp version**: 85c40c9 (includes PR #18302)

## Current Working Configuration

### Optimized Settings
```bash
--device Vulkan0,Vulkan1 \
--split-mode layer \
--tensor-split 2,1 \
--n-gpu-layers -1 \
--ctx-size 32768
```

**Tensor Split**: 2:1 ratio (67% Intel / 33% Nvidia)
- Vulkan0 (Intel): ~14.7 GB model + 160 MB KV cache
- Vulkan1 (Nvidia): ~8.6 GB model + 32 MB KV cache
- **Key**: Leaves ~1-2 GB free on each GPU for compute buffers

## Previous Issues (Now Resolved)

### Issue History

#### Phase 1: Initial Failures (3:2 tensor-split)
**Problem:** Out of memory at 445 tokens during inference
```
ggml_vulkan: Device memory allocation of size 306216960 failed.
ggml_vulkan: vk::Device::allocateMemory: ErrorOutOfDeviceMemory
```

**Root Cause:** 3:2 split (60% Intel / 40% Nvidia) didn't leave enough free VRAM for compute buffers during large prompt processing.

**Result:** ❌ Crashed consistently on 509 token prompts

#### Phase 2: Overcorrection (4:1 tensor-split)
**Problem:** Model won't load, Intel GPU overloaded
```
llama_params_fit_impl: Vulkan0 (Intel): 16288 total, 18113 used, 3454 deficit
alloc_tensor_range: failed to allocate Vulkan0 buffer
```

**Root Cause:** 4:1 split put too much on Intel Arc (18.1 GB > 16 GB available)

**Result:** ❌ Model failed to load

#### Phase 3: Balanced Solution (2:1 tensor-split)
**Configuration:** 67% Intel / 33% Nvidia
- Intel: 14.7 GB (1.3 GB free)
- Nvidia: 8.6 GB (3.4 GB free)

**Result:** ✅ Stable with 32K context, handles 509+ token prompts without crashes

### Critical Fix: llama.cpp PR #18302

**Merged:** 2025-12-24
**Commit:** 2a9ea20 → 85c40c9

**What it fixed:**
- Vulkan command buffer corruption in `ggml_backend_vk_event_wait`
- Added proper context cleanup: `ggml_vk_ctx_end()` and `ctx->transfer_ctx.reset()`
- Resolves multi-GPU crash issues

**Impact:** Essential for dual GPU stability. Earlier versions crash on multi-GPU setups.

## Performance Benchmarks

### With Optimized Dual GPU (2:1 split, 32K context)

**Nemotron Nano 30B MoE:**
- Prompt processing: ~493 tok/s
- Generation: ~40 tok/s
- Stability: ✅ No crashes with 509+ token prompts
- Memory: ~23.3 GB total model size

**Qwen2.5 Coder 32B:**
- Expected: ~25 tok/s generation
- Memory: ~18 GB model size
- Status: Configured, not yet benchmarked

**DeepSeek V2 Lite 16B:**
- Expected: ~30 tok/s generation
- Memory: ~9 GB model size
- Status: Configured, not yet benchmarked

### Comparison: Single GPU vs Dual GPU

| Configuration | Model | Performance | Status |
|--------------|-------|-------------|--------|
| Single GPU (Intel) | Nemotron 30B | ~20-25 tok/s (est) | Works but slower |
| **Dual GPU (2:1)** | **Nemotron 30B** | **~40 tok/s** | ✅ **Stable** |
| Single GPU (CUDA) | Qwen 7B | ~80 tok/s | ✅ Fast, preferred |

## Configuration Evolution

| Attempt | Tensor Split | Context | Result | Reason |
|---------|-------------|---------|--------|--------|
| 1 | 3:2 (60/40) | 16K | ❌ OOM at 445 tokens | Not enough free VRAM |
| 2 | 4:1 (80/20) | 16K | ❌ Won't load | Intel overloaded |
| 3 | 2:1 (67/33) | 16K | ✅ Stable | Balanced |
| 4 | 2:1 (67/33) | 24K | ✅ Stable | More context |
| **5** | **2:1 (67/33)** | **32K** | ✅ **Production** | **Optimal** |

## Current Makefile Configuration

```makefile
# Large models - Dual GPU Vulkan (stable)
NEMOTRON_NANO_ARGS = --ctx-size 32768 --device Vulkan0,Vulkan1 --n-gpu-layers -1 --split-mode layer --tensor-split 2,1 --threads 8
QWEN32B_ARGS = --ctx-size 32768 --device Vulkan0,Vulkan1 --n-gpu-layers -1 --split-mode layer --tensor-split 2,1 --threads 8
DEEPSEEK_ARGS = --ctx-size 32768 --device Vulkan0,Vulkan1 --n-gpu-layers -1 --split-mode layer --tensor-split 2,1 --threads 8
```

## Monitoring and Debugging

### Check Current Status
```bash
# Detailed model info
make model-status

# Shows:
# - GPU allocation per device
# - Memory usage and free space
# - KV cache distribution
# - Memory fit analysis (deficit/surplus)
```

### Test Stability
```bash
# Run benchmark with large prompts
./benchmark.sh

# Select model 3, 4, or 5 for dual GPU testing
# Tests with 509 token prompts
```

### View GPU Usage
```bash
# Nvidia GPU
nvidia-smi -l 1

# Intel GPU
intel_gpu_top

# Or combined
make gpu-check
```

## Troubleshooting Guide

### If Crashes Occur

1. **Check llama.cpp version:**
   ```bash
   ~/.local/bin/llama-server --version
   # Should show: version: 4 (85c40c9) or later
   ```

2. **Verify memory allocation:**
   ```bash
   make model-status
   # Check "Memory Fit Analysis" section
   # Intel should show < 1GB deficit
   # Nvidia should show > 1GB surplus
   ```

3. **Test with smaller context:**
   ```bash
   # Edit Makefile, reduce context 32K → 24K → 16K
   # Then restart: make restart
   ```

4. **Check logs for specific errors:**
   ```bash
   grep -E "error|crash|Out|failed" /tmp/llama-server.log | tail -20
   ```

### Known Limitations

1. **Context vs Memory**: Larger context = more KV cache memory needed
   - 32K context: ~192 MB KV cache (stable)
   - 48K context: ~288 MB KV cache (untested, may cause issues)

2. **Tensor Split Trade-offs**:
   - More to Intel: Better utilization of larger VRAM, but less headroom
   - More to Nvidia: More free space, but underutilizes Intel's 16GB

3. **Model Size Limits**:
   - Current config stable up to ~23 GB models
   - Larger models may need single GPU mode (Intel only)

## Alternative Configurations

### If Dual GPU Issues Persist

**Option 1: Single GPU (Intel Arc - More VRAM)**
```bash
# Edit Makefile
QWEN32B_ARGS = --ctx-size 32768 --device Vulkan0 --n-gpu-layers -1 --threads 8
```
- Pro: 16GB VRAM, simpler, more stable
- Con: Slower than dual GPU (~25 tok/s vs ~40 tok/s)

**Option 2: Single GPU (Nvidia - CUDA)**
```bash
# For smaller models only
QWEN_ARGS = --ctx-size 32768 --device CUDA0 --n-gpu-layers -1 --threads 8
```
- Pro: Faster for small models (~80 tok/s)
- Con: Limited to 12GB VRAM

## Reporting Issues to Upstream

If you encounter new issues:

1. **Gather information:**
   ```bash
   ~/.local/bin/llama-server --version
   make model-status
   tail -100 /tmp/llama-server.log
   ```

2. **Report to llama.cpp:**
   - Repository: https://github.com/ggml-org/llama.cpp/issues
   - Component: Vulkan backend
   - Include: Version, GPU info, error logs, configuration

## Model-Specific Issues

### DeepSeek-Coder-V2-Lite-Instruct (16B) - Vulkan Incompatibility

**Issue Discovered**: 2025-12-25

**Problem**: Gibberish output when running on Vulkan backend (both dual and single GPU)
- Example outputs: "utaciizzizzzz", "Executor", "是z�z�z�"
- Model loads successfully, no memory errors
- Server reports healthy status
- Inference produces random tokens instead of coherent text

**Attempted Fixes**:
1. ❌ Disabling flash attention (`--flash-attn 0`): No improvement
2. ❌ Dual GPU Vulkan with 2:1 split: Still gibberish
3. ❌ Single GPU Vulkan (Intel Arc only): Still gibberish
4. ✅ **Single GPU CUDA (Nvidia RTX 4070)**: **Works perfectly!**

**Root Cause**: Vulkan backend incompatibility with DeepSeek model architecture
- Likely related to model-specific attention mechanisms or token processing
- Not a memory issue, not a flash attention issue
- Specific to this model architecture with Vulkan backend

**Solution**: Use CUDA backend instead of Vulkan
```bash
# Working configuration
DEEPSEEK_ARGS = --ctx-size 32768 --device CUDA0 --n-gpu-layers -1 --threads 8
```

**Performance with CUDA**:
- Prompt processing: 77 tok/s
- Generation: 33 tok/s
- Memory usage: ~9.7 GB on Nvidia RTX 4070
- Context: 32K tokens
- Status: ✅ Stable and producing correct outputs

**Conclusion**: DeepSeek-Coder-V2-Lite-Instruct must use CUDA backend. Vulkan produces corrupted inference output.

### Qwen2.5-Coder-32B - Context Limitation

**Issue Discovered**: 2025-12-25

**Problem**: Out of memory when loading with 32K context on dual GPU Vulkan
- Error: `ErrorOutOfDeviceMemory` - failed to allocate 1GB KV buffer on Intel Arc
- Model size: ~18.5 GB (denser than Nemotron 30B MoE)
- KV cache requirement: 1 GB for 32K context
- Intel Arc capacity: 16 GB (insufficient with full 32K KV cache)

**Solution**: Reduced context from 32K → 16K
```bash
# Working configuration
QWEN32B_ARGS = --ctx-size 16384 --device Vulkan0,Vulkan1 --n-gpu-layers -1 --split-mode layer --tensor-split 2,1 --threads 8
```

**Performance with 16K context**:
- Memory allocation: ~18.5 GB model + 512 MB KV cache
- Status: ✅ Loads successfully on dual GPU Vulkan
- Context: 16K tokens (sufficient for most coding tasks)

**Note**: Qwen 32B is denser than Nemotron Nano 30B MoE despite similar parameter count, requiring more VRAM per token.

### Qwen2.5-Coder-32B - Vulkan Corruption + Memory Issues (BROKEN)

**Issue Discovered**: 2025-12-25

**Problem 1**: Work group assertion failure with default configuration
```
GGML_ASSERT(wg0 <= ctx->device->properties.limits.maxComputeWorkGroupCount[0] && ...)
```
- Occurs with default batch size (2048) during inference
- Triggers when processing 525+ token batches

**Problem 2**: Out of memory with 32K context
- Error: `ErrorOutOfDeviceMemory` - failed to allocate 1GB KV buffer
- Model size: ~18.5 GB + 1 GB KV cache (32K) = exceeds Intel Arc 16GB

**Problem 3**: Gibberish output on Vulkan backend (ALL configurations)
- With 16K context + reduced batch sizes: Model loads successfully
- Example outputs: "0000000000...", "9999999999...", ". . . . . ."
- Occurs on both dual GPU and single GPU Vulkan
- Same corruption pattern as DeepSeek

**Attempted Configurations**:
1. ❌ 32K context, dual GPU, 2048 batch: Work group assertion failure
2. ❌ 16K context, dual GPU, 2048 batch: Out of memory (1GB KV cache)
3. ❌ 16K context, dual GPU, 512 batch: Loads but produces gibberish
4. ❌ 16K context, single GPU (Intel), 512 batch: Still gibberish
5. ❌ 32K context, dual GPU, 512 batch: Out of memory again

**Root Causes**:
- Memory: Model too dense for 32K context on 16GB Intel Arc (needs ~19.5GB total)
- Vulkan Corruption: Same inference quality issue as DeepSeek
- Work Groups: Model dimensions exceed Vulkan device work group limits with large batches

**Why CUDA doesn't work**:
- Model requires ~18GB VRAM minimum
- Nvidia RTX 4070 only has 12GB
- Cannot fit even with aggressive offloading

**Conclusion**: ❌ **Qwen2.5-Coder-32B is NOT USABLE with current hardware/software**

**Alternative**: Use **Qwen2.5-Coder-7B** instead
- Works perfectly on single GPU CUDA
- 82.31 tok/s average performance
- 32K context supported
- No Vulkan issues

---

## Future Improvements

Potential optimizations to try:
- [ ] Test with larger models (48B+) if memory allows
- [ ] Experiment with different batch sizes
- [ ] Try 48K context (may need single GPU)
- [ ] Test with future llama.cpp releases for performance improvements
- [ ] Monitor llama.cpp for DeepSeek Vulkan backend fixes

## Upstream llama.cpp Bug: Vulkan Gibberish Output

**Critical Discovery**: 2025-12-25

### Issue
All models on Vulkan backend produce gibberish output on Intel GPUs with Mesa drivers.

### Affected Hardware
- **GPU**: Intel Arc A770 (DG2)
- **Driver**: Intel open-source Mesa driver (version 25.1.7)
- **Backend**: Vulkan
- **Models**: ALL models (Nemotron Nano 30B, Qwen 32B, DeepSeek 16B, etc.)

### Symptoms
- Model loads successfully without errors
- Generates gibberish tokens: "0000000000...", "9999999999...", ". . . . . ."
- Prompt processing works (fast speeds measured)
- Output quality completely corrupted
- CPU backend works correctly (slower but accurate)

### Upstream Tracking
- **GitHub Issue**: [#17106 - Misc. bug: Vulkan output is gibberish](https://github.com/ggml-org/llama.cpp/issues/17106)
- **Status**: REOPENED (as of November 16, 2025)
- **Resolution**: None yet - active bug in llama.cpp
- **Similar Issues**: #17797 (ROCm), #16881 (Android), #13310 (LM Studio)

### Root Cause
Vulkan backend computation error specific to Intel GPUs with Mesa drivers. The exact cause is under investigation by llama.cpp maintainers. Related to matrix multiplication or Flash Attention implementation in Vulkan shader code.

### Impact on This Setup
- ❌ **Nemotron Nano 30B**: Cannot use (requires Vulkan dual GPU)
- ❌ **Qwen 32B**: Cannot use (Vulkan broken + memory constraints + too large for CUDA)
- ✅ **DeepSeek 16B**: Fixed by switching to CUDA backend
- ✅ **All small models**: Work on CUDA (unaffected)

### Workarounds
1. **Use CUDA backend**: Works for models ≤12GB (Nvidia RTX 4070)
2. **Use CPU backend**: Add `--device CPU` or `-ngl 0` (very slow but accurate)
3. **Wait for fix**: Monitor GitHub issue #17106 for updates

### Our Configuration
```bash
# Affected (produces gibberish)
--device Vulkan0              # Intel Arc A770
--device Vulkan0,Vulkan1      # Intel + Nvidia dual GPU

# Working (accurate output)
--device CUDA0                # Nvidia RTX 4070 only
--device CPU                  # CPU inference (slow)
```

### False Positive Benchmarks
**Note**: Earlier benchmarks showed "31.47 tok/s" for Nemotron Nano on Vulkan, measuring **speed only**, not output quality. The model was generating gibberish at that speed, which went undetected by the benchmark script.

---

## Conclusion

Dual GPU Vulkan mode is **NOT usable** due to upstream llama.cpp bug:

### 🚨 Critical Bug Status
**Vulkan backend is BROKEN** due to upstream llama.cpp bug [#17106](https://github.com/ggml-org/llama.cpp/issues/17106):
- **Affects**: ALL models on Intel Arc A770 with Mesa drivers
- **Symptom**: Gibberish output regardless of configuration
- **Status**: Open bug, no fix yet (as of 2025-12-25)
- **Impact**: Cannot use dual GPU mode or Intel Arc GPU

### ✅ Working Configuration (CUDA Only)
- **Backend**: CUDA (Nvidia RTX 4070 only)
- **Context**: 32K tokens
- **Models**: Limited to ≤12GB VRAM
- **Performance**: 33-133 tok/s depending on model
- **Stability**: Fully tested and stable

### 📊 Production Status
**3 working models (CUDA only):**
- Nemotron Mini 4B: 132.65 tok/s ✅
- Qwen 7B: 82.31 tok/s ✅
- DeepSeek 16B: 33 tok/s ✅

**2 broken models:**
- Nemotron Nano 30B: Vulkan bug (requires dual GPU, produces gibberish) ❌
- Qwen 32B: Vulkan bug + memory constraints + too large for CUDA ❌

## Last Tested
- **Date**: 2025-12-25
- **llama.cpp version**: 85c40c9 (includes PR #18302)
- **Build**: Native with GCC 13, CUDA 12.9, Vulkan drivers
- **Status**: ✅ Production ready, stable with 32K context
