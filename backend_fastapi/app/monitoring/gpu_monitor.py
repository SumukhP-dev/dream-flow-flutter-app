"""
GPU monitoring utilities for tracking GPU usage and performance.
"""

import logging
from typing import Optional, Dict, Any

logger = logging.getLogger(__name__)

try:
    import torch
    TORCH_AVAILABLE = True
except ImportError:
    TORCH_AVAILABLE = False

try:
    import pynvml
    PYNVML_AVAILABLE = True
except ImportError:
    PYNVML_AVAILABLE = False


def get_gpu_info() -> Optional[Dict[str, Any]]:
    """
    Get GPU information and current usage.
    
    Returns:
        Dictionary with GPU info, or None if GPU not available
    """
    if not TORCH_AVAILABLE:
        return None
    
    if not torch.cuda.is_available():
        return None
    
    try:
        device_count = torch.cuda.device_count()
        if device_count == 0:
            return None
        
        # Get primary GPU (device 0)
        device = torch.cuda.current_device()
        device_name = torch.cuda.get_device_name(device)
        
        # Get memory info using PyTorch
        memory_allocated = torch.cuda.memory_allocated(device) / (1024 ** 3)  # GB
        memory_reserved = torch.cuda.memory_reserved(device) / (1024 ** 3)  # GB
        
        # Try to get total memory using pynvml if available
        total_memory = None
        memory_utilization = None
        gpu_utilization = None
        
        if PYNVML_AVAILABLE:
            try:
                pynvml.nvmlInit()
                handle = pynvml.nvmlDeviceGetHandleByIndex(device)
                mem_info = pynvml.nvmlDeviceGetMemoryInfo(handle)
                total_memory = mem_info.total / (1024 ** 3)  # GB
                
                # Get utilization
                util = pynvml.nvmlDeviceGetUtilizationRates(handle)
                gpu_utilization = util.gpu
                memory_utilization = util.memory
            except Exception as e:
                logger.warning(f"Failed to get detailed GPU info via pynvml: {e}")
        
        # Fallback: estimate total memory from reserved (usually close)
        if total_memory is None:
            # Common GPU memory sizes
            common_sizes = [8, 12, 16, 24, 40, 48, 80]
            # Estimate based on reserved memory
            for size in common_sizes:
                if memory_reserved < size:
                    total_memory = size
                    break
            if total_memory is None:
                total_memory = memory_reserved * 1.2  # Rough estimate
        
        return {
            "device_name": device_name,
            "device_index": device,
            "total_memory_gb": round(total_memory, 2),
            "memory_allocated_gb": round(memory_allocated, 2),
            "memory_reserved_gb": round(memory_reserved, 2),
            "memory_free_gb": round(total_memory - memory_reserved, 2),
            "memory_utilization_percent": memory_utilization,
            "gpu_utilization_percent": gpu_utilization,
            "cuda_available": True,
        }
    except Exception as e:
        logger.error(f"Failed to get GPU info: {e}", exc_info=True)
        return None


def log_gpu_status() -> None:
    """Log current GPU status to logger."""
    gpu_info = get_gpu_info()
    if gpu_info:
        logger.info(
            f"GPU: {gpu_info['device_name']} | "
            f"Memory: {gpu_info['memory_allocated_gb']:.2f}/{gpu_info['total_memory_gb']:.2f} GB | "
            f"Utilization: {gpu_info.get('gpu_utilization_percent', 'N/A')}%",
            extra={"gpu_info": gpu_info}
        )
    else:
        logger.info("No GPU available or GPU monitoring not available")


def check_gpu_memory(min_free_gb: float = 1.0) -> tuple[bool, Optional[float]]:
    """
    Check if GPU has enough free memory.
    
    Args:
        min_free_gb: Minimum free memory required in GB
    
    Returns:
        Tuple of (has_enough_memory, free_memory_gb)
    """
    gpu_info = get_gpu_info()
    if not gpu_info:
        return False, None
    
    free_memory = gpu_info.get("memory_free_gb", 0)
    has_enough = free_memory >= min_free_gb
    
    return has_enough, free_memory

