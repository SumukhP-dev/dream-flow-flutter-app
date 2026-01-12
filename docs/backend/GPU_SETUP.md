# GPU Setup Guide for High-Performance Systems

This guide explains how to set up GPU acceleration for Dream Flow backend on systems with NVIDIA GPUs (RTX 4060, etc.).

## Prerequisites

- NVIDIA GPU with CUDA support (RTX 4060, RTX 3090, etc.)
- CUDA Toolkit 11.8+ or 12.1+
- cuDNN 8.6+
- Python 3.10+

## Step 1: Install CUDA Toolkit

### Windows
1. Download CUDA Toolkit from [NVIDIA Developer](https://developer.nvidia.com/cuda-downloads)
2. Install CUDA Toolkit (recommended: CUDA 11.8 or 12.1)
3. Verify installation:
   ```powershell
   nvcc --version
   ```

### Linux
```bash
# Ubuntu/Debian
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update
sudo apt-get -y install cuda-toolkit-12-1
```

## Step 2: Install PyTorch with CUDA

```bash
# For CUDA 11.8
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# For CUDA 12.1
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
```

Verify GPU is detected:
```python
import torch
print(torch.cuda.is_available())
print(torch.cuda.get_device_name(0))
```

## Step 3: Install llama-cpp-python with CUDA

```bash
# Uninstall CPU-only version
pip uninstall llama-cpp-python

# Install with CUDA support
CMAKE_ARGS="-DLLAMA_CUBLAS=on" pip install llama-cpp-python --no-cache-dir
```

For Windows, you may need Visual Studio Build Tools:
```powershell
# Install Visual Studio Build Tools first
# Then run:
$env:CMAKE_ARGS="-DLLAMA_CUBLAS=on"
pip install llama-cpp-python --no-cache-dir
```

## Step 4: Install Other Dependencies

```bash
cd backend_fastapi
pip install -r requirements.txt

# Additional GPU-optimized packages
pip install xformers  # Optional: faster attention (if available)
```

## Step 5: Configure Environment Variables

Copy `.env.high_performance.example` to `.env`:

```bash
cp .env.high_performance.example .env
```

Edit `.env` and set:
```env
STORY_MODEL_USE_GPU=true
STORY_MODEL_GPU_LAYERS=35
LOCAL_VIDEO_USE_GPU=true
LOCAL_VIDEO_GPU_MEMORY_FRACTION=0.85
LOW_MEMORY_MODE=false
```

## Step 6: Download Models

The backend will automatically download models on first run:
- **Story Model**: Llama 3.2 3B Instruct (~2GB)
- **Image Model**: Stable Diffusion v1.5 (~4GB)
- **Video Model**: AnimateDiff motion adapter (~500MB)

## Step 7: Verify GPU Acceleration

Start the server:
```bash
cd backend_fastapi
python -m uvicorn app.main:app --host 0.0.0.0 --port 8080
```

Check logs for GPU detection:
```
Using GPU: NVIDIA GeForce RTX 4060
GPU acceleration enabled: 35 layers on GPU
```

## Troubleshooting

### GPU Not Detected

1. **Check CUDA installation**:
   ```bash
   nvidia-smi
   ```

2. **Verify PyTorch CUDA**:
   ```python
   import torch
   print(torch.cuda.is_available())  # Should be True
   ```

3. **Check llama-cpp-python**:
   ```python
   from llama_cpp import Llama
   # Should not raise import errors
   ```

### Out of Memory Errors

1. **Reduce GPU layers**:
   ```env
   STORY_MODEL_GPU_LAYERS=20  # Instead of 35
   ```

2. **Reduce video quality**:
   ```env
   LOCAL_VIDEO_QUALITY=fast
   VIDEO_RESOLUTION=384x384
   ```

3. **Limit concurrent requests**:
   ```env
   MAX_CONCURRENT_REQUESTS=1
   ```

### Slow Performance

1. **Check GPU utilization**:
   ```bash
   nvidia-smi -l 1
   ```

2. **Enable xformers** (if available):
   ```bash
   pip install xformers
   ```

3. **Use torch.compile** (PyTorch 2.0+):
   Already enabled automatically if available

## Performance Expectations

With RTX 4060 (8GB VRAM):
- **Story Generation**: 5-15 seconds (vs 30-120s CPU)
- **Image Generation**: 2-5 seconds per image (vs 30-60s CPU)
- **Video Generation**: 30-60 seconds (vs 2-4min CPU)
- **Total Pipeline**: 30-90 seconds (vs 3-5min CPU)

## Next Steps

- Monitor GPU memory usage: `nvidia-smi`
- Adjust quality settings based on your needs
- Consider upgrading to larger models (7B, 13B) if you have more VRAM

