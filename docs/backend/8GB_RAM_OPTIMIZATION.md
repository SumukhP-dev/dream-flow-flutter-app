# 8GB RAM Optimization Guide

This document explains the optimizations made to run Dream Flow backend on systems with 8GB RAM or less.

## Overview

The backend has been optimized to work efficiently on low-memory systems (8GB RAM) by:

1. **Reduced model memory footprint**
2. **Memory monitoring and warnings**
3. **Configurable low-memory mode**
4. **Placeholder images instead of image generation**

## Memory Usage Breakdown

### Current Setup (with optimizations)

| Component | Memory Usage | Notes |
|-----------|--------------|-------|
| TinyLlama Model | ~1-2 GB | Memory-mapped (doesn't fully load into RAM) |
| Backend Server | ~200-500 MB | FastAPI + dependencies |
| System Overhead | ~2-3 GB | Windows + background processes |
| **Total** | **~4-6 GB** | Leaves ~2-4 GB free |

### With Image Generation (Disabled by Default)

| Component | Memory Usage | Notes |
|-----------|--------------|-------|
| Stable Diffusion | +2-4 GB | Only if enabled |
| **Total** | **~6-10 GB** | Exceeds 8GB - not recommended |

## Optimizations Applied

### 1. Reduced Context Window

**Standard Mode:**
- Context window: 1024 tokens (reduced from 2048)
- Saves ~1 GB of memory

**Low Memory Mode (`LOW_MEMORY_MODE=true`):**
- Context window: 512 tokens
- Saves ~1.5 GB of memory

### 2. Smaller Batch Sizes

**Standard Mode:**
- Batch size: 256 (reduced from 512)
- Saves ~400 MB of memory

**Low Memory Mode:**
- Batch size: 128
- Saves ~600 MB of memory

### 3. Limited Thread Count

**Standard Mode:**
- Max threads: 4
- Balanced performance/memory

**Low Memory Mode:**
- Max threads: 2
- Reduces memory pressure

### 4. Reduced Token Limits

**Standard Mode:**
- Max tokens per story: 256
- Generates ~1000 characters

**Low Memory Mode:**
- Max tokens per story: 128
- Generates ~500 characters

### 5. Memory-Mapped Model Loading

- Uses `use_mmap=True` - model weights are memory-mapped
- Doesn't load entire model into RAM
- Only loads needed portions during inference

### 6. Placeholder Images

- Image generation disabled by default
- Uses lightweight placeholder images instead
- Saves 2-4 GB of memory

## Configuration

### Enable Low Memory Mode

Set the `LOW_MEMORY_MODE` environment variable:

```bash
# Windows PowerShell
$env:LOW_MEMORY_MODE="true"

# Windows CMD
set LOW_MEMORY_MODE=true

# Linux/Mac
export LOW_MEMORY_MODE=true
```

Or add to `.env` file:

```env
LOW_MEMORY_MODE=true
LOCAL_INFERENCE=true
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LOW_MEMORY_MODE` | `false` | Enable aggressive memory optimizations |
| `LOCAL_INFERENCE` | `false` | Enable local inference (required) |
| `LOCAL_MODEL_PATH` | `./models/tinyllama-...` | Path to model file |

## Performance Impact

### Story Generation Times

| Mode | Context | Batch | Tokens | Time (approx) |
|------|---------|-------|--------|---------------|
| Standard | 1024 | 256 | 256 | 2-5 minutes |
| Low Memory | 512 | 128 | 128 | 3-7 minutes |

*Times are approximate and depend on CPU speed*

### Memory Usage Comparison

| Mode | Model RAM | Total RAM | Free RAM |
|------|-----------|-----------|----------|
| Standard | ~2 GB | ~5 GB | ~3 GB |
| Low Memory | ~1 GB | ~4 GB | ~4 GB |

## Recommendations for 8GB Systems

### ✅ Recommended Settings

```env
LOCAL_INFERENCE=true
LOW_MEMORY_MODE=true
```

### ✅ Best Practices

1. **Close unnecessary applications** before running the server
2. **Keep laptop plugged in** to avoid power throttling
3. **Use placeholder images** (default) - don't enable image generation
4. **Monitor memory usage** - check Task Manager
5. **Restart server** if memory usage grows over time

### ❌ Don't Do

1. **Don't enable image generation** - requires 6-10 GB RAM
2. **Don't run multiple instances** - one server at a time
3. **Don't run heavy games/apps** simultaneously
4. **Don't use high-quality video settings** - stick to "fast" mode

## Troubleshooting

### Out of Memory Errors

If you see `MemoryError` or `VideoGenerationMemoryError`:

1. **Enable low memory mode:**
   ```bash
   set LOW_MEMORY_MODE=true
   ```

2. **Close other applications:**
   - Check Task Manager for memory hogs
   - Close browsers, IDEs, games

3. **Restart the server:**
   ```bash
   # Stop current server
   # Then restart with LOW_MEMORY_MODE=true
   ```

4. **Check available memory:**
   ```python
   import psutil
   mem = psutil.virtual_memory()
   print(f"Available: {mem.available / (1024**3):.2f} GB")
   ```

### Slow Generation

If story generation is very slow (>10 minutes):

1. **Check CPU usage** - ensure CPU isn't throttled
2. **Check memory pressure** - high memory usage slows down
3. **Reduce story length** - shorter stories generate faster
4. **Use fewer scenes** - fewer scenes = less processing

### Model Won't Load

If model loading fails:

1. **Check disk space** - model file is ~600 MB
2. **Check memory** - need at least 1.5 GB free
3. **Check model file** - ensure download completed
4. **Try single-threaded mode** - may work if multi-threaded fails

## Monitoring Memory Usage

### Windows Task Manager

1. Open Task Manager (Ctrl+Shift+Esc)
2. Go to "Performance" tab
3. Check "Memory" section
4. Look for Python processes

### PowerShell Script

```powershell
# Check Python process memory
Get-Process python | Select-Object ProcessName, @{Name="Memory(MB)";Expression={$_.WS/1MB}}
```

### Python Script

```python
import psutil
import os

# Check current process memory
process = psutil.Process(os.getpid())
mem_info = process.memory_info()
print(f"Current process: {mem_info.rss / (1024**3):.2f} GB")

# Check system memory
mem = psutil.virtual_memory()
print(f"Total: {mem.total / (1024**3):.2f} GB")
print(f"Available: {mem.available / (1024**3):.2f} GB")
print(f"Used: {mem.used / (1024**3):.2f} GB")
print(f"Percent: {mem.percent}%")
```

## Expected Behavior

### Normal Operation

- ✅ Server starts successfully
- ✅ Model loads in 10-30 seconds
- ✅ Story generation completes in 2-7 minutes
- ✅ Memory usage stays under 6 GB
- ✅ No memory errors

### Warning Signs

- ⚠️ Model loading takes >1 minute
- ⚠️ Story generation takes >10 minutes
- ⚠️ Memory usage >7 GB
- ⚠️ System becomes slow/unresponsive

### Error Conditions

- ❌ `MemoryError` during model loading
- ❌ `VideoGenerationMemoryError` during generation
- ❌ System freezes or crashes
- ❌ Server crashes repeatedly

## Summary

With these optimizations, Dream Flow backend can run on 8GB RAM systems:

- ✅ **Memory usage**: ~4-6 GB (leaves 2-4 GB free)
- ✅ **Performance**: 2-7 minutes per story
- ✅ **Reliability**: Stable with proper configuration
- ✅ **Compatibility**: Works on Windows, Linux, Mac

**Key setting**: Set `LOW_MEMORY_MODE=true` for best results on 8GB systems.

