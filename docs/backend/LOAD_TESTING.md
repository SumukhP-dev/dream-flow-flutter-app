# Load Testing Guide

This guide explains how to run load tests for the `/api/v1/story` endpoint using Locust and monitor system resources.

## Prerequisites

Install the required dependencies:

```bash
pip install -r requirements.txt
```

This will install:
- `locust` - Load testing framework
- `psutil` - System resource monitoring
- `gputil` - GPU monitoring (optional)

## Quick Start

### 1. Start the API Server

Make sure your FastAPI server is running:

```bash
cd backend_fastapi
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### 2. Run Load Test with Monitoring

Use the automated test runner:

```bash
python run_load_test.py --host=http://localhost:8000 --users=200 --duration=300
```

This will:
- Start resource monitoring (CPU, memory, GPU)
- Run Locust with 200 concurrent users for 5 minutes
- Generate HTML report and metrics CSV
- Save all results to `load_test_results/`

### 3. View Results

After the test completes, check:
- **HTML Report**: `load_test_results/locust_report_*.html` - Open in browser for detailed stats
- **Metrics CSV**: `load_test_results/metrics_*.csv` - Resource usage over time
- **Log File**: `load_test_results/locust_*.log` - Detailed request logs

## Manual Testing

### Run Locust Only

```bash
# Interactive mode (opens web UI at http://localhost:8089)
locust -f locustfile.py --host=http://localhost:8000

# Headless mode
locust -f locustfile.py --host=http://localhost:8000 --users=200 --spawn-rate=10 --run-time=5m --headless
```

### Monitor Resources Only

```bash
# Monitor for 5 minutes, sampling every 1 second
python monitor_resources.py --output metrics.csv --interval 1 --duration 300

# Monitor indefinitely (until Ctrl+C)
python monitor_resources.py --output metrics.csv --interval 1
```

## Test Configuration

### Load Test Parameters

- `--host`: Base URL of the API (required)
- `--users`: Number of concurrent users (default: 200)
- `--spawn-rate`: Users to spawn per second (default: 10)
- `--duration`: Test duration in seconds (default: 300)
- `--monitor-interval`: Resource sampling interval in seconds (default: 1.0)
- `--output-dir`: Directory to save results (default: load_test_results)

### Example Configurations

**Quick Smoke Test (1 minute, 50 users):**
```bash
python run_load_test.py --host=http://localhost:8000 --users=50 --duration=60
```

**Heavy Load Test (10 minutes, 500 users):**
```bash
python run_load_test.py --host=http://localhost:8000 --users=500 --spawn-rate=20 --duration=600
```

**Gradual Ramp-up (200 users over 2 minutes):**
```bash
python run_load_test.py --host=http://localhost:8000 --users=200 --spawn-rate=2 --duration=120
```

## Resource Monitoring

The resource monitor tracks:

- **CPU Usage**: Percentage utilization
- **Memory Usage**: Total, used, available (GB) and percentage
- **GPU Usage** (if available): Load, memory usage, temperature

Metrics are saved to CSV with timestamps for analysis. You can:
- Import into Excel/Python for visualization
- Plot graphs to identify resource bottlenecks
- Compare metrics across different test runs

## Understanding Results

### Locust Metrics

- **Total Requests**: Total number of requests sent
- **Requests/sec**: Throughput (RPS)
- **Response Times**: Min, max, median, 95th percentile, 99th percentile
- **Failure Rate**: Percentage of failed requests

### Resource Metrics

- **CPU Spikes**: Indicates processing bottlenecks
- **Memory Growth**: Watch for memory leaks (should stabilize)
- **GPU Utilization**: Important if using GPU-accelerated models

## Troubleshooting

### High Failure Rate

- Check API server logs for errors
- Verify server has enough resources
- Reduce `--users` or increase `--spawn-rate` for gradual ramp-up
- Check network connectivity

### Resource Exhaustion

- Monitor CPU/memory during test
- Reduce concurrent users if resources are maxed out
- Check for resource leaks (memory should stabilize, not grow continuously)

### MoviePy Resource Leaks

The `stitch_video` function has been patched to ensure proper cleanup of `AudioFileClip` and `ImageClip` objects. If you notice:
- Memory growth during video processing
- File handle leaks
- GPU memory not being released

Check that all clips are properly closed in the `finally` block.

## Best Practices

1. **Start Small**: Begin with fewer users and shorter duration
2. **Monitor Resources**: Always run with resource monitoring enabled
3. **Check Logs**: Review both Locust and API server logs
4. **Gradual Ramp-up**: Use lower spawn rates for production-like testing
5. **Clean Environment**: Ensure no other heavy processes are running
6. **Baseline First**: Run a baseline test before making changes

## Integration with CI/CD

You can integrate load tests into your CI/CD pipeline:

```bash
# Exit code 0 on success, non-zero on failure
python run_load_test.py --host=$API_URL --users=100 --duration=60
```

Note: Ensure your CI environment has sufficient resources for load testing.

