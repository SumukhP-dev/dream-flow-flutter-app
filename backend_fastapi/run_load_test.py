"""
Run Locust load tests with resource monitoring.

This script:
1. Starts resource monitoring in the background
2. Runs Locust load tests
3. Collects and reports results

Usage:
    python run_load_test.py --host=http://localhost:8000 --users=200 --spawn-rate=10 --duration=300
"""

import argparse
import subprocess
import sys
import time
import signal
import os
from pathlib import Path
from datetime import datetime


def run_load_test(
    host: str,
    users: int = 200,
    spawn_rate: int = 10,
    duration: int = 300,
    monitor_interval: float = 1.0,
    output_dir: str = "load_test_results",
):
    """
    Run Locust load test with resource monitoring.
    
    Args:
        host: Base URL of the API (e.g., http://localhost:8000)
        users: Number of concurrent users
        spawn_rate: Users to spawn per second
        duration: Test duration in seconds
        monitor_interval: Resource monitoring interval in seconds
        output_dir: Directory to save results
    """
    # Create output directory
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    # Resource monitoring output file
    metrics_file = output_path / f"metrics_{timestamp}.csv"
    
    # Locust output files
    locust_log = output_path / f"locust_{timestamp}.log"
    locust_html = output_path / f"locust_report_{timestamp}.html"
    
    print("=" * 80)
    print("Load Test Configuration")
    print("=" * 80)
    print(f"Host: {host}")
    print(f"Users: {users}")
    print(f"Spawn Rate: {spawn_rate} users/sec")
    print(f"Duration: {duration} seconds")
    print(f"Output Directory: {output_path}")
    print("=" * 80)
    print()
    
    # Start resource monitoring
    print("Starting resource monitoring...")
    monitor_process = subprocess.Popen(
        [
            sys.executable,
            "monitor_resources.py",
            "--output",
            str(metrics_file),
            "--interval",
            str(monitor_interval),
            "--duration",
            str(duration + 10),  # Monitor slightly longer than test
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    
    # Give monitor a moment to start
    time.sleep(2)
    
    if monitor_process.poll() is not None:
        print("ERROR: Resource monitoring failed to start")
        sys.exit(1)
    
    print(f"Resource monitoring started (PID: {monitor_process.pid})")
    print(f"Metrics will be saved to: {metrics_file}")
    print()
    
    # Run Locust
    print("Starting Locust load test...")
    print()
    
    locust_cmd = [
        "locust",
        "-f",
        "locustfile.py",
        "--host",
        host,
        "--users",
        str(users),
        "--spawn-rate",
        str(spawn_rate),
        "--run-time",
        f"{duration}s",
        "--headless",
        "--html",
        str(locust_html),
        "--logfile",
        str(locust_log),
        "--loglevel",
        "INFO",
    ]
    
    try:
        locust_process = subprocess.run(
            locust_cmd,
            check=False,
            capture_output=False,
        )
        
        locust_exit_code = locust_process.returncode
        
    except KeyboardInterrupt:
        print("\nLoad test interrupted by user")
        locust_exit_code = 130
    except Exception as e:
        print(f"ERROR: Locust test failed: {e}")
        locust_exit_code = 1
    
    # Stop resource monitoring
    print("\nStopping resource monitoring...")
    try:
        monitor_process.terminate()
        monitor_process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        monitor_process.kill()
        monitor_process.wait()
    except Exception as e:
        print(f"Warning: Error stopping monitor: {e}")
    
    # Summary
    print()
    print("=" * 80)
    print("Load Test Summary")
    print("=" * 80)
    print(f"Locust Exit Code: {locust_exit_code}")
    print(f"Results Directory: {output_path}")
    print(f"  - Metrics: {metrics_file}")
    print(f"  - HTML Report: {locust_html}")
    print(f"  - Log: {locust_log}")
    print("=" * 80)
    
    if locust_exit_code == 0:
        print("✓ Load test completed successfully")
    else:
        print("✗ Load test completed with errors")
        sys.exit(locust_exit_code)


def main():
    parser = argparse.ArgumentParser(
        description="Run Locust load tests with resource monitoring",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic test with 200 users for 5 minutes
  python run_load_test.py --host=http://localhost:8000 --users=200 --duration=300
  
  # Quick test with 50 users for 1 minute
  python run_load_test.py --host=http://localhost:8000 --users=50 --duration=60
        """,
    )
    parser.add_argument(
        "--host",
        required=True,
        help="Base URL of the API (e.g., http://localhost:8000)",
    )
    parser.add_argument(
        "--users",
        type=int,
        default=200,
        help="Number of concurrent users (default: 200)",
    )
    parser.add_argument(
        "--spawn-rate",
        type=int,
        default=10,
        help="Users to spawn per second (default: 10)",
    )
    parser.add_argument(
        "--duration",
        type=int,
        default=300,
        help="Test duration in seconds (default: 300)",
    )
    parser.add_argument(
        "--monitor-interval",
        type=float,
        default=1.0,
        help="Resource monitoring interval in seconds (default: 1.0)",
    )
    parser.add_argument(
        "--output-dir",
        default="load_test_results",
        help="Directory to save results (default: load_test_results)",
    )
    
    args = parser.parse_args()
    
    run_load_test(
        host=args.host,
        users=args.users,
        spawn_rate=args.spawn_rate,
        duration=args.duration,
        monitor_interval=args.monitor_interval,
        output_dir=args.output_dir,
    )


if __name__ == "__main__":
    main()

