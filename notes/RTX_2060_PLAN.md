# RTX 2060 Integration Plan

**Date**: 2025-12-25
**Status**: Ready to install RTX 2060, system reboot pending

---

## Current System Status

### Working Hardware
- **RTX 4070** (12GB) - CUDA ✅ Working
- **Intel Arc A770** (16GB) - Vulkan ❌ Broken (llama.cpp bug #17106)

### Working Models (CUDA Only)
- Nemotron Mini 4B: 132.65 tok/s ✅
- Qwen 7B: 82.31 tok/s ✅ (Current default)
- DeepSeek 16B: 33 tok/s ✅

### Broken Models (Vulkan Bug)
- Nemotron Nano 30B: Requires dual GPU (Vulkan broken)
- Qwen 32B: Too large for 12GB CUDA + Vulkan broken

---

## RTX 2060 Specifications

### Expected Specs
- **VRAM**: 6GB (base) or 8GB (Super)
- **CUDA Cores**: 1920 (base) or 2176 (Super)
- **Architecture**: Turing (CUDA 7.5)
- **TDP**: 160W (base) or 175W (Super)

---

## Potential Benefits of Adding RTX 2060

### Option 1: Dual NVIDIA CUDA Setup ⭐ **BEST OPTION**

**Configuration**: RTX 4070 (12GB) + RTX 2060 (6-8GB)

**Benefits:**
- ✅ Total CUDA VRAM: **18-20GB**
- ✅ Can run larger models with tensor parallelism
- ✅ No Vulkan bug (both CUDA)
- ✅ Potentially run Qwen 32B or Nemotron Nano 30B
- ✅ Replace broken Intel Arc setup

**Possible Models:**
- **Qwen2.5-Coder-32B**: 18GB model could fit!
- **Nemotron Nano 30B**: ~23GB (might need quantization)
- **DeepSeek 16B**: More headroom
- **Multiple small models** simultaneously

**Tools to Use:**
- vLLM with tensor parallelism (`--tensor-parallel-size 2`)
- llama.cpp with dual CUDA (`--device CUDA0,CUDA1`)
- Text Generation WebUI with multi-GPU

### Option 2: Dedicated Task GPU

**Use Cases:**
- RTX 4070: Main inference (Qwen 7B, DeepSeek 16B)
- RTX 2060: Background tasks, smaller models
- Run multiple models simultaneously

### Option 3: Development/Testing GPU

**Use Cases:**
- Keep RTX 4070 for production
- Use RTX 2060 for testing new models
- Experiment without affecting main setup

---

## Setup Steps After Reboot

### 1. Verify GPU Detection
```bash
# Check all NVIDIA GPUs
nvidia-smi

# Should show:
# GPU 0: RTX 4070 (12GB)
# GPU 1: RTX 2060 (6-8GB)

# Check CUDA visibility
echo $CUDA_VISIBLE_DEVICES
```

### 2. Test Basic CUDA Access
```bash
# Test both GPUs
python3 -c "import torch; print(torch.cuda.device_count())"
# Should output: 2

# Check GPU names
python3 -c "import torch; print([torch.cuda.get_device_name(i) for i in range(torch.cuda.device_count())])"
```

### 3. Test llama-server with Dual CUDA
```bash
# Stop current server
make stop

# Test with both GPUs (update Makefile first)
# Add to a model config:
# --device CUDA0,CUDA1 --split-mode layer --tensor-split 2,1

# Example for Qwen 32B (if it fits):
~/.local/bin/llama-server \
  --model /data/llama-models/bartowski_Qwen2.5-Coder-32B-Instruct-GGUF_Qwen2.5-Coder-32B-Instruct-Q4_K_M.gguf \
  --ctx-size 16384 \
  --device CUDA0,CUDA1 \
  --n-gpu-layers -1 \
  --split-mode layer \
  --tensor-split 2,1 \
  --threads 8 \
  --port 11336
```

### 4. Update Makefile Configuration

Add dual CUDA configuration for large models:

```makefile
# Dual CUDA (RTX 4070 + RTX 2060)
QWEN32B_ARGS = --ctx-size 16384 --device CUDA0,CUDA1 --n-gpu-layers -1 --split-mode layer --tensor-split 2,1 --threads 8

NEMOTRON_NANO_ARGS = --ctx-size 32768 --device CUDA0,CUDA1 --n-gpu-layers -1 --split-mode layer --tensor-split 2,1 --threads 8
```

**Tensor Split Explanation:**
- `--tensor-split 2,1` = 67% RTX 4070 / 33% RTX 2060
- Adjust based on actual VRAM (12GB vs 6/8GB)
- `2,1` ratio is optimal for 12GB + 6GB
- Could try `3,2` for 12GB + 8GB (Super)

---

## Expected Performance

### With Dual CUDA (RTX 4070 + RTX 2060)

| Model | VRAM Needed | Fits? | Expected Performance |
|-------|-------------|-------|---------------------|
| **Qwen 32B (Q4)** | ~18GB | ✅ Yes | 20-30 tok/s |
| **Nemotron Nano 30B** | ~23GB | ⚠️  Tight | 15-25 tok/s (if fits) |
| **DeepSeek 16B** | ~9GB | ✅ Easy | 40-50 tok/s |
| **Qwen 7B** | ~4GB | ✅ Easy | 100+ tok/s |

---

## Comparison: Before vs After

### Before (RTX 4070 Only)
- ✅ Qwen 7B, DeepSeek 16B, Nemotron Mini 4B
- ❌ Cannot run 30B+ models
- ❌ 12GB VRAM limit

### After (RTX 4070 + RTX 2060)
- ✅ All small models
- ✅ **Qwen 32B becomes viable!**
- ✅ Nemotron Nano 30B might fit
- ✅ 18-20GB total VRAM

### vs Broken Dual GPU (4070 + Arc A770)
- **Before**: 28GB total, but Vulkan broken
- **After**: 18-20GB total, but **all CUDA (works!)**
- **Trade-off**: Less VRAM, but actually functional

---

## Alternative: Replace Intel Arc Entirely?

### Consideration
Since Intel Arc A770 is broken with Vulkan:
- Could remove Intel Arc A770
- Keep RTX 4070 + RTX 2060 (dual CUDA)
- Simpler, more reliable setup
- Less power consumption
- Still get 18-20GB VRAM

**Pros:**
- ✅ More stable (no Vulkan issues)
- ✅ Less power/heat
- ✅ Simpler configuration

**Cons:**
- ❌ Lose potential 16GB when Vulkan is fixed
- ❌ Lose upgrade path for future

**Recommendation**: Keep Intel Arc installed but unused until llama.cpp fixes Vulkan bug

---

## Next Steps (Resume Here After Reboot)

1. ✅ **Install RTX 2060** physically - **DONE**
2. ✅ **Reboot system** - **DONE**
3. ✅ **Verify detection**: Run `nvidia-smi` - **DONE: Both GPUs detected**
4. ✅ **Test CUDA access**: Check both GPUs visible - **DONE: PyTorch sees both**
5. ✅ **Update Makefile**: Add dual CUDA configs - **DONE**
6. ✅ **Test Qwen 32B**: See if it fits in 18-20GB - **TESTED: Too large**
7. ✅ **Benchmark**: Compare performance - **DONE: See results below**
8. ✅ **Update docs**: Document dual CUDA setup - **IN PROGRESS**

---

## Test Results (2025-12-25)

### Hardware Configuration
- **GPU 0** (CUDA0): RTX 4070 - 12GB VRAM
- **GPU 1** (CUDA1): RTX 2060 - 6GB VRAM
- **Total VRAM**: 18GB
- **Build**: CUDA-only (Vulkan disabled due to Intel Arc bug)

### Dual CUDA Setup: ✅ WORKING
- llama.cpp successfully built with CUDA support only
- Both GPUs detected and accessible
- Tensor parallelism working with `--device CUDA0,CUDA1 --split-mode layer --tensor-split 2,1`

### Model Test Results

| Model | Size (disk) | Size (loaded) | Result | Notes |
|-------|-------------|---------------|--------|-------|
| **Qwen 7B** | 4.4 GB | ~6GB | ✅ Loads | Slower on dual GPU (76 tok/s vs 82 tok/s single) |
| **DeepSeek 16B** | 9.7 GB | ~12GB | ❓ Untested | Should work on single GPU |
| **Qwen 32B** | 18 GB | ~23GB | ❌ Too large | Needs 15GB CUDA0 + 8GB CUDA1 = 23GB total |
| **Nemotron Nano 30B** | 23 GB | ~28GB | ❌ Too large | Needs 15GB CUDA0 + 8GB CUDA1 = 23GB base + KV cache |

### Key Findings

**The 18GB VRAM Problem:**
1. **Small models (< 12GB)**: Work but run *slower* on dual GPU due to communication overhead
2. **Large models (> 18GB)**: Don't fit even with dual GPU

**Why Dual GPU Isn't Helping:**
- Tensor parallelism adds overhead for inter-GPU communication
- Small models that fit in single GPU don't benefit
- Large models that would benefit don't fit in 18GB total

**What Would Help:**
- RTX 2060 **Super (8GB)** instead of base (6GB) → 20GB total → Qwen 32B might fit
- RTX 3060 (12GB) → 24GB total → Both Qwen 32B and Nemotron Nano 30B would fit
- RTX 4060 Ti (16GB) → 28GB total → All models would fit comfortably

### Recommendations

**Short Term:**
- Use **Qwen 7B** or **DeepSeek 16B** on **single GPU** (RTX 4070 only)
- Disable dual CUDA for these models (overhead not worth it)
- Keep RTX 2060 for future use if you upgrade

**Long Term:**
- Consider replacing RTX 2060 6GB with **RTX 3060 12GB** or better
- OR wait for llama.cpp Vulkan bug fix to use Intel Arc A770 (16GB)
  - Vulkan bug: [#17106](https://github.com/ggml-org/llama.cpp/issues/17106)

### Working Configuration

**Single GPU (Recommended):**
```bash
# Qwen 7B - 82 tok/s
make use-qwen

# DeepSeek 16B - 33 tok/s
make use-deepseek
```

**Dual CUDA (For Testing):**
- Works but slower for small models
- Large models don't fit anyway
- Not recommended with current hardware

---

## Key Files to Update After Testing

1. `Makefile` - Add dual CUDA configurations
2. `README.md` - Update hardware section
3. `FINAL_STATUS.md` - Update to show 18-20GB VRAM available
4. `CHANGELOG.md` - Add RTX 2060 integration notes
5. `VULKAN_ISSUES.md` - Note CUDA workaround with dual NVIDIA

---

## Questions to Answer After Reboot

- [ ] What is the exact model? (RTX 2060 6GB or Super 8GB?)
- [ ] Does `nvidia-smi` show both GPUs?
- [ ] Can llama-server use both CUDA devices?
- [ ] Does Qwen 32B fit in 18-20GB?
- [ ] What's the actual performance?
- [ ] Should we keep Intel Arc or remove it?

---

## Useful Commands Reference

```bash
# Check all GPUs
nvidia-smi
lspci | grep -i vga

# Test Python CUDA
python3 -c "import torch; print(f'GPUs: {torch.cuda.device_count()}')"

# llama-server with dual CUDA
~/.local/bin/llama-server --help | grep -A5 "device"

# Monitor GPU usage during inference
watch -n 1 nvidia-smi

# Check power draw
nvidia-smi dmon -s pucvmet
```

---

## Current Known Issues to Track

1. **llama.cpp Vulkan Bug**: [#17106](https://github.com/ggml-org/llama.cpp/issues/17106)
   - Affects Intel Arc A770 + Mesa
   - No fix yet (as of 2025-12-25)
   - Monitoring for updates

2. **Qwen 32B Memory**:
   - Needs ~18-19GB total
   - RTX 4070 (12GB) + RTX 2060 (6-8GB) = should fit
   - Test with reduced context if needed

---

## Success Criteria

✅ **Minimum Success**: Both GPUs detected and usable
✅ **Good Success**: Can run Qwen 32B on dual CUDA
✅ **Excellent Success**: Better performance than single GPU setup

---

**Ready to resume after reboot!**
Run: `cat /home/sree/Matrix/localcode/RTX_2060_PLAN.md`
