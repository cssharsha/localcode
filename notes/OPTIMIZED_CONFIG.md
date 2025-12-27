# Optimized Dual GPU Configuration

**Date**: 2025-12-25
**Status**: ✅ Tested and Stable
**llama.cpp version**: commit 85c40c9 (includes PR #18302 Vulkan multi-GPU fix)

## Final Configuration

### Small Models (Single GPU - CUDA on Nvidia RTX 4070)
- **Nemotron Mini 4B**: 32K context, 132.65 tok/s average
- **Qwen2.5 Coder 7B**: 32K context, 82.31 tok/s average
- **DeepSeek V2 Lite 16B**: 32K context, 33 tok/s (Vulkan incompatible)
- **Performance**: Stable, fast inference

### Large Models (Dual GPU - Vulkan on Intel Arc A770 + Nvidia RTX 4070)
- **Nemotron Nano 30B MoE**: 32K context, 2:1 tensor-split, 31.47 tok/s average

### ❌ Broken Models
- **Qwen2.5 Coder 32B**: Vulkan corruption (gibberish output) + memory constraints
  - All configurations tested failed
  - Not viable on current hardware/software
  - Use Qwen 7B or Nemotron Nano 30B instead

**Tensor Split**: `2,1` = 67% Intel Arc / 33% Nvidia RTX

## Performance Metrics

### Benchmark Results (32K context, optimized configuration)

**From /tmp/benchmark_results.json** - Latest results with 32K context:

| Model | GPU Config | Avg Speed | Summary Task | Edit Task | Memory |
|-------|-----------|-----------|--------------|-----------|--------|
| **Nemotron Mini 4B** | Single (CUDA) | **132.65 tok/s** | 122.17 tok/s | 143.14 tok/s | ~7.8 GB |
| **Qwen 7B** | Single (CUDA) | **82.31 tok/s** | 77.16 tok/s | 87.47 tok/s | ~7.4 GB |
| **Nemotron Nano 30B** | Dual (Vulkan 2:1) | **31.47 tok/s** | 32.96 tok/s | 29.99 tok/s | ~10.3 GB |
| **DeepSeek 16B** | Single (CUDA) | **33 tok/s** | N/A | N/A | ~9.7 GB |

**Notes:**
- All models tested with 32K context window
- DeepSeek benchmark (56.98 tok/s) was on Vulkan before discovering corruption issue
- Current DeepSeek configuration uses CUDA (33 tok/s actual)
- Nemotron Nano also shows ~493 tok/s prompt processing in production use

### ❌ Models Unable to Benchmark

- **Qwen2.5 Coder 32B**: Vulkan corruption prevents reliable testing
  - Produces gibberish output on all Vulkan configurations
  - Too large for CUDA on 12GB GPU

## Memory Allocation

```
Intel Arc A770 (16GB):    14719 MB model + 160 MB KV cache
Nvidia RTX 4070 (12GB):    8555 MB model +  32 MB KV cache
Total Model Size:         ~23.3 GB
```

## Evolution of Configuration

### Initial Setup (FAILED)
- Context: 4K-8K
- Tensor-split: 3:2 (60% Intel / 40% Nvidia)
- Result: ❌ Crashed at 445 tokens with `ErrorOutOfDeviceMemory`

### Attempted Fix 1 (FAILED)
- Tensor-split: 4:1 (80% Intel / 20% Nvidia)
- Result: ❌ Model won't load, Intel GPU overloaded (3454 MB deficit)

### Final Optimized (SUCCESS) ✅
- Context: 32K tokens (2x-8x larger than initial)
- Tensor-split: 2:1 (67% Intel / 33% Nvidia)
- Result: ✅ Stable, faster, 2x larger context window

## Key Insights

1. **Memory Headroom Critical**: Must leave ~700-1000 MB free on each GPU for compute buffers
2. **Tensor-Split Balance**: 2:1 ratio balances model distribution while leaving compute headroom
3. **Context Scaling**: 32K context works with proper memory management
4. **Vulkan PR #18302**: Essential fix for dual GPU stability (merged 2025-12-24)

## Quick Commands

```bash
# Restore this configuration
/tmp/restore_optimized_config.sh

# Test small model (single GPU)
make use-qwen
curl -s http://localhost:11336/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Hello"}],"max_tokens":10}'

# Test large model (dual GPU)
make use-nemotron-nano
curl -s http://localhost:11336/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Hello"}],"max_tokens":10}'

# Run benchmark
./benchmark.sh
```

## Troubleshooting

### If you see "ErrorOutOfDeviceMemory":
1. Reduce context size (32K → 24K → 16K)
2. Adjust tensor-split to give more to GPU with more RAM
3. Check if other GPU processes are using memory

### If model won't load:
1. Try single GPU mode: `--device Vulkan0` (Intel Arc only)
2. Reduce batch size or layers
3. Check GPU memory with `nvidia-smi` and `intel_gpu_top`

## Notes

- **PR #18302 Required**: Earlier llama.cpp versions crash due to Vulkan command buffer corruption
- **Single GPU Alternative**: Intel Arc A770 (16GB) can handle most models alone if dual GPU issues persist
- **Context vs Performance**: Larger context = slightly more memory, but performance remains stable
