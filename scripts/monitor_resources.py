"""
Resource monitoring script for load testing.

Monitors CPU, memory, and GPU usage during load tests.
Outputs metrics to a CSV file for analysis.

Usage:
    python monitor_resources.py --output metrics.csv --interval 1
"""

import argparse
import csv
import time
import sys
from datetime import datetime
from pathlib import Path

try:
    import psutil
except ImportError:
    print("Error: psutil not installed. Install with: pip install psutil")
    sys.exit(1)

try:
    import GPUtil
    GPU_AVAILABLE = True
except ImportError:
    GPU_AVAILABLE = False
    print("Warning: GPUtil not available. GPU monitoring disabled. Install with: pip install gputil")


def get_cpu_usage() -> float:
    """Get current CPU usage percentage."""
    return psutil.cpu_percent(interval=0.1)


def get_memory_usage() -> dict:
    """Get current memory usage statistics."""
    mem = psutil.virtual_memory()
    return {
        "total_gb": mem.total / (1024 ** 3),
        "available_gb": mem.available / (1024 ** 3),
        "used_gb": mem.used / (1024 ** 3),
        "percent": mem.percent,
    }


def get_gpu_usage() -> list[dict]:
    """Get GPU usage statistics if available."""
    if not GPU_AVAILABLE:
        return []
    
    try:
        gpus = GPUtil.getGPUs()
        return [
            {
                "id": gpu.id,
                "name": gpu.name,
                "load_percent": gpu.load * 100,
                "memory_used_mb": gpu.memoryUsed,
                "memory_total_mb": gpu.memoryTotal,
                "memory_percent": (gpu.memoryUsed / gpu.memoryTotal) * 100,
                "temperature_c": gpu.temperature,
            }
            for gpu in gpus
        ]
    except Exception as e:
        print(f"Warning: Could not get GPU stats: {e}")
        return []


def monitor_resources(output_file: str, interval: float = 1.0, duration: float = None):
    """
    Monitor system resources and write to CSV.
    
    Args:
        output_file: Path to output CSV file
        interval: Sampling interval in seconds
        duration: Total monitoring duration in seconds (None for indefinite)
    """
    start_time = time.time()
    output_path = Path(output_file)
    
    # Prepare CSV headers
    headers = [
        "timestamp",
        "cpu_percent",
        "memory_total_gb",
        "memory_used_gb",
        "memory_available_gb",
        "memory_percent",
    ]
    
    # Add GPU headers if available
    if GPU_AVAILABLE:
        try:
            gpus = GPUtil.getGPUs()
            for i in range(len(gpus)):
                headers.extend([
                    f"gpu_{i}_load_percent",
                    f"gpu_{i}_memory_used_mb",
                    f"gpu_{i}_memory_total_mb",
                    f"gpu_{i}_memory_percent",
                    f"gpu_{i}_temperature_c",
                ])
        except Exception:
            pass
    
    # Write headers
    with open(output_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
    
    print(f"Monitoring resources... Output: {output_path}")
    print(f"Interval: {interval}s, Duration: {duration or 'indefinite'}s")
    print("Press Ctrl+C to stop")
    
    try:
        while True:
            current_time = time.time()
            elapsed = current_time - start_time
            
            if duration and elapsed >= duration:
                break
            
            # Collect metrics
            timestamp = datetime.now().isoformat()
            cpu = get_cpu_usage()
            mem = get_memory_usage()
            gpus = get_gpu_usage()
            
            # Build row
            row = [
                timestamp,
                cpu,
                mem["total_gb"],
                mem["used_gb"],
                mem["available_gb"],
                mem["percent"],
            ]
            
            # Add GPU data
            if GPU_AVAILABLE and gpus:
                for gpu in gpus:
                    row.extend([
                        gpu["load_percent"],
                        gpu["memory_used_mb"],
                        gpu["memory_total_mb"],
                        gpu["memory_percent"],
                        gpu["temperature_c"],
                    ])
            elif GPU_AVAILABLE:
                # Fill with zeros if no GPUs detected
                num_gpus = len(GPUtil.getGPUs()) if hasattr(GPUtil, 'getGPUs') else 0
                for _ in range(num_gpus):
                    row.extend([0, 0, 0, 0, 0])
            
            # Write row
            with open(output_path, "a", newline="") as f:
                writer = csv.writer(f)
                writer.writerow(row)
            
            # Print status
            print(
                f"[{elapsed:.1f}s] CPU: {cpu:.1f}% | "
                f"Memory: {mem['percent']:.1f}% ({mem['used_gb']:.2f}GB/{mem['total_gb']:.2f}GB)",
                end=""
            )
            if gpus:
                for gpu in gpus:
                    print(f" | GPU {gpu['id']}: {gpu['load_percent']:.1f}% ({gpu['memory_percent']:.1f}%)", end="")
            print()
            
            time.sleep(interval)
    
    except KeyboardInterrupt:
        print("\nMonitoring stopped by user")
    
    print(f"\nMetrics saved to: {output_path}")


def main():
    parser = argparse.ArgumentParser(description="Monitor system resources during load tests")
    parser.add_argument(
        "--output",
        default="resource_metrics.csv",
        help="Output CSV file path (default: resource_metrics.csv)",
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=1.0,
        help="Sampling interval in seconds (default: 1.0)",
    )
    parser.add_argument(
        "--duration",
        type=float,
        default=None,
        help="Total monitoring duration in seconds (default: indefinite)",
    )
    
    args = parser.parse_args()
    monitor_resources(args.output, args.interval, args.duration)


if __name__ == "__main__":
    main()

