"""
Performance monitoring and benchmarking for AI inference.

Tracks and reports:
- Execution times for each inference mode
- Memory usage
- Model loading times
- API response times
- Throughput metrics

Usage:
    python tests/performance_monitor.py
    python tests/performance_monitor.py --mode cloud
    python tests/performance_monitor.py --mode local
    python tests/performance_monitor.py --iterations 10
"""

import os
import sys
import time
import asyncio
import json
import psutil
import statistics
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any
from dataclasses import dataclass, asdict

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

# Set minimal environment
os.environ.setdefault('SUPABASE_SERVICE_ROLE_KEY', 'test_key')
os.environ.setdefault('SUPABASE_URL', 'https://test.supabase.co')
os.environ.setdefault('SUPABASE_ANON_KEY', 'test_anon_key')


@dataclass
class PerformanceMetric:
    """Single performance measurement."""
    operation: str
    mode: str
    duration_seconds: float
    memory_mb: float
    success: bool
    error: str = ""
    timestamp: str = ""
    
    def __post_init__(self):
        if not self.timestamp:
            self.timestamp = datetime.now().isoformat()


@dataclass
class BenchmarkResults:
    """Aggregated benchmark results."""
    operation: str
    mode: str
    iterations: int
    mean_duration: float
    median_duration: float
    std_dev: float
    min_duration: float
    max_duration: float
    mean_memory_mb: float
    success_rate: float
    total_time: float


class PerformanceMonitor:
    """Monitor and benchmark AI inference performance."""
    
    def __init__(self, output_dir: Path = None):
        self.output_dir = output_dir or Path(__file__).parent / "performance_results"
        self.output_dir.mkdir(exist_ok=True)
        self.metrics: List[PerformanceMetric] = []
    
    async def measure_operation(
        self,
        operation_name: str,
        mode: str,
        coroutine_func,
        *args,
        **kwargs
    ) -> PerformanceMetric:
        """Measure a single operation."""
        process = psutil.Process()
        mem_before = process.memory_info().rss / 1024 / 1024  # MB
        
        start_time = time.time()
        success = False
        error = ""
        
        try:
            await coroutine_func(*args, **kwargs)
            success = True
        except Exception as e:
            error = str(e)
            print(f"❌ {operation_name} failed: {e}")
        
        duration = time.time() - start_time
        mem_after = process.memory_info().rss / 1024 / 1024
        memory_used = mem_after - mem_before
        
        metric = PerformanceMetric(
            operation=operation_name,
            mode=mode,
            duration_seconds=duration,
            memory_mb=memory_used,
            success=success,
            error=error
        )
        
        self.metrics.append(metric)
        return metric
    
    async def benchmark_story_generation(self, mode: str, iterations: int = 5):
        """Benchmark story generation."""
        print(f"\n{'='*60}")
        print(f"Benchmarking Story Generation ({mode} mode)")
        print(f"Iterations: {iterations}")
        print(f"{'='*60}\n")
        
        # Set mode
        os.environ['AI_INFERENCE_MODE'] = mode
        if mode in ['server_only', 'server_first']:
            os.environ['LOCAL_INFERENCE'] = 'true'
        
        from app.core.prompting import PromptBuilder, PromptContext
        from app.core.guardrails import PromptSanitizer
        
        sanitizer = PromptSanitizer()
        prompt_builder = PromptBuilder(sanitizer=sanitizer)
        context = PromptContext(
            prompt="A short bedtime story",
            theme="ocean",
            mood="calm",
            target_length=200,
        )
        
        # Get appropriate generator
        if mode in ['cloud_only', 'cloud_first']:
            from app.core.services import StoryGenerator
            story_gen = StoryGenerator(prompt_builder=prompt_builder)
        else:
            from app.core.local_services import LocalStoryGenerator
            story_gen = LocalStoryGenerator(prompt_builder=prompt_builder)
        
        # Run iterations
        for i in range(iterations):
            print(f"Iteration {i+1}/{iterations}...", end=" ")
            metric = await self.measure_operation(
                "story_generation",
                mode,
                story_gen.generate,
                context
            )
            status = "✅" if metric.success else "❌"
            print(f"{status} {metric.duration_seconds:.2f}s (mem: {metric.memory_mb:.1f}MB)")
    
    async def benchmark_narration_generation(self, mode: str, iterations: int = 5):
        """Benchmark narration generation."""
        print(f"\n{'='*60}")
        print(f"Benchmarking Narration Generation ({mode} mode)")
        print(f"Iterations: {iterations}")
        print(f"{'='*60}\n")
        
        os.environ['AI_INFERENCE_MODE'] = mode
        
        from app.core.prompting import PromptBuilder, PromptContext
        from app.core.guardrails import PromptSanitizer
        from unittest.mock import MagicMock, AsyncMock
        
        sanitizer = PromptSanitizer()
        prompt_builder = PromptBuilder(sanitizer=sanitizer)
        context = PromptContext(
            prompt="Test story",
            theme="ocean",
            mood="calm",
            target_length=100,
        )
        
        story_text = "Once upon a time, by the peaceful ocean."
        
        # Mock Supabase
        mock_supabase = MagicMock()
        mock_supabase.upload_audio = AsyncMock(
            return_value="https://test.supabase.co/audio/test.wav"
        )
        
        # Get appropriate generator
        if mode in ['cloud_only', 'cloud_first']:
            from app.core.services import NarrationGenerator
            narration_gen = NarrationGenerator(prompt_builder=prompt_builder)
        else:
            from app.core.local_services import LocalNarrationGenerator
            narration_gen = LocalNarrationGenerator(prompt_builder=prompt_builder)
        
        # Run iterations
        for i in range(iterations):
            print(f"Iteration {i+1}/{iterations}...", end=" ")
            metric = await self.measure_operation(
                "narration_generation",
                mode,
                narration_gen.synthesize,
                story_text,
                context,
                "alloy",
                mock_supabase
            )
            status = "✅" if metric.success else "❌"
            print(f"{status} {metric.duration_seconds:.2f}s (mem: {metric.memory_mb:.1f}MB)")
    
    async def benchmark_visual_generation(self, mode: str, iterations: int = 3):
        """Benchmark visual generation."""
        print(f"\n{'='*60}")
        print(f"Benchmarking Visual Generation ({mode} mode)")
        print(f"Iterations: {iterations}")
        print(f"{'='*60}\n")
        
        os.environ['AI_INFERENCE_MODE'] = mode
        os.environ['USE_PLACEHOLDERS_ONLY'] = 'false'
        
        from app.core.prompting import PromptBuilder, PromptContext
        from app.core.guardrails import PromptSanitizer
        from unittest.mock import MagicMock, AsyncMock
        
        sanitizer = PromptSanitizer()
        prompt_builder = PromptBuilder(sanitizer=sanitizer)
        context = PromptContext(
            prompt="A peaceful ocean scene",
            theme="ocean",
            mood="calm",
            target_length=100,
        )
        
        story_text = "A peaceful ocean with gentle waves."
        
        # Mock Supabase
        mock_supabase = MagicMock()
        mock_supabase.upload_frame = AsyncMock(
            side_effect=lambda data, filename: f"https://test.supabase.co/frames/{filename}"
        )
        
        # Get appropriate generator
        if mode in ['cloud_only', 'cloud_first']:
            from app.core.services import VisualGenerator
            visual_gen = VisualGenerator(prompt_builder=prompt_builder)
        else:
            from app.core.local_services import LocalVisualGenerator
            visual_gen = LocalVisualGenerator(prompt_builder=prompt_builder)
        
        # Run iterations
        for i in range(iterations):
            print(f"Iteration {i+1}/{iterations}...", end=" ")
            metric = await self.measure_operation(
                "visual_generation",
                mode,
                visual_gen.create_frames,
                story_text,
                context,
                2,  # num_scenes
                mock_supabase
            )
            status = "✅" if metric.success else "❌"
            print(f"{status} {metric.duration_seconds:.2f}s (mem: {metric.memory_mb:.1f}MB)")
    
    def calculate_benchmarks(self) -> List[BenchmarkResults]:
        """Calculate aggregate statistics from metrics."""
        # Group by operation and mode
        groups: Dict[tuple, List[PerformanceMetric]] = {}
        
        for metric in self.metrics:
            key = (metric.operation, metric.mode)
            if key not in groups:
                groups[key] = []
            groups[key].append(metric)
        
        # Calculate statistics for each group
        results = []
        for (operation, mode), metrics in groups.items():
            durations = [m.duration_seconds for m in metrics if m.success]
            memories = [m.memory_mb for m in metrics]
            success_count = sum(1 for m in metrics if m.success)
            
            if not durations:
                continue
            
            result = BenchmarkResults(
                operation=operation,
                mode=mode,
                iterations=len(metrics),
                mean_duration=statistics.mean(durations),
                median_duration=statistics.median(durations),
                std_dev=statistics.stdev(durations) if len(durations) > 1 else 0.0,
                min_duration=min(durations),
                max_duration=max(durations),
                mean_memory_mb=statistics.mean(memories),
                success_rate=success_count / len(metrics),
                total_time=sum(durations)
            )
            results.append(result)
        
        return results
    
    def print_summary(self):
        """Print benchmark summary."""
        results = self.calculate_benchmarks()
        
        print(f"\n{'='*60}")
        print("BENCHMARK SUMMARY")
        print(f"{'='*60}\n")
        
        for result in results:
            print(f"{result.operation} ({result.mode}):")
            print(f"  Iterations: {result.iterations}")
            print(f"  Mean time:   {result.mean_duration:.3f}s")
            print(f"  Median time: {result.median_duration:.3f}s")
            print(f"  Std dev:     {result.std_dev:.3f}s")
            print(f"  Min time:    {result.min_duration:.3f}s")
            print(f"  Max time:    {result.max_duration:.3f}s")
            print(f"  Memory:      {result.mean_memory_mb:.1f}MB avg")
            print(f"  Success:     {result.success_rate*100:.0f}%")
            print()
    
    def save_results(self):
        """Save results to JSON file."""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Save individual metrics
        metrics_file = self.output_dir / f"metrics_{timestamp}.json"
        with open(metrics_file, 'w') as f:
            json.dump(
                [asdict(m) for m in self.metrics],
                f,
                indent=2
            )
        print(f"✅ Saved metrics to {metrics_file}")
        
        # Save benchmark results
        results = self.calculate_benchmarks()
        results_file = self.output_dir / f"benchmarks_{timestamp}.json"
        with open(results_file, 'w') as f:
            json.dump(
                [asdict(r) for r in results],
                f,
                indent=2
            )
        print(f"✅ Saved benchmarks to {results_file}")
        
        # Save summary report
        report_file = self.output_dir / f"report_{timestamp}.txt"
        with open(report_file, 'w') as f:
            f.write(f"AI Inference Performance Report\n")
            f.write(f"Generated: {datetime.now().isoformat()}\n")
            f.write(f"{'='*60}\n\n")
            
            for result in results:
                f.write(f"{result.operation} ({result.mode}):\n")
                f.write(f"  Mean: {result.mean_duration:.3f}s ± {result.std_dev:.3f}s\n")
                f.write(f"  Range: {result.min_duration:.3f}s - {result.max_duration:.3f}s\n")
                f.write(f"  Memory: {result.mean_memory_mb:.1f}MB\n")
                f.write(f"  Success: {result.success_rate*100:.0f}%\n\n")
        
        print(f"✅ Saved report to {report_file}")


async def main():
    """Run performance benchmarks."""
    import argparse
    
    parser = argparse.ArgumentParser(description="AI Inference Performance Monitor")
    parser.add_argument('--mode', choices=['cloud', 'local', 'both'], default='both',
                       help='Inference mode to benchmark')
    parser.add_argument('--iterations', type=int, default=5,
                       help='Number of iterations per test')
    parser.add_argument('--operations', nargs='+', 
                       choices=['story', 'narration', 'visual', 'all'],
                       default=['all'],
                       help='Operations to benchmark')
    
    args = parser.parse_args()
    
    monitor = PerformanceMonitor()
    
    modes = []
    if args.mode == 'both':
        modes = ['cloud_only', 'server_only']
    elif args.mode == 'cloud':
        modes = ['cloud_only']
    else:
        modes = ['server_only']
    
    operations = args.operations
    if 'all' in operations:
        operations = ['story', 'narration', 'visual']
    
    print(f"\n🚀 Starting Performance Benchmarks")
    print(f"   Modes: {', '.join(modes)}")
    print(f"   Operations: {', '.join(operations)}")
    print(f"   Iterations: {args.iterations}")
    
    for mode in modes:
        if 'story' in operations:
            try:
                await monitor.benchmark_story_generation(mode, args.iterations)
            except Exception as e:
                print(f"❌ Story benchmark failed: {e}")
        
        if 'narration' in operations:
            try:
                await monitor.benchmark_narration_generation(mode, args.iterations)
            except Exception as e:
                print(f"❌ Narration benchmark failed: {e}")
        
        if 'visual' in operations:
            try:
                await monitor.benchmark_visual_generation(mode, args.iterations)
            except Exception as e:
                print(f"❌ Visual benchmark failed: {e}")
    
    monitor.print_summary()
    monitor.save_results()
    
    print(f"\n✅ Benchmarking complete!")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
