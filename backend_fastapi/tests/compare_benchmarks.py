#!/usr/bin/env python3
"""
Compare performance benchmarks to detect regressions or improvements.

Usage:
    python compare_benchmarks.py baseline.json current.json
    python compare_benchmarks.py  # Uses latest two benchmark files
"""

import json
import sys
import glob
from pathlib import Path
from datetime import datetime


class Colors:
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    BOLD = '\033[1m'
    RESET = '\033[0m'


def load_benchmark(file_path: str) -> dict:
    """Load benchmark file and return as dict keyed by (operation, mode)."""
    with open(file_path) as f:
        benchmarks = json.load(f)
    
    return {(b['operation'], b['mode']): b for b in benchmarks}


def find_latest_benchmarks() -> tuple:
    """Find the two most recent benchmark files."""
    results_dir = Path(__file__).parent / "performance_results"
    benchmark_files = sorted(
        glob.glob(str(results_dir / "benchmarks_*.json")),
        key=lambda x: Path(x).stat().st_mtime,
        reverse=True
    )
    
    if len(benchmark_files) < 2:
        print(f"{Colors.RED}❌ Need at least 2 benchmark files to compare{Colors.RESET}")
        sys.exit(1)
    
    return benchmark_files[1], benchmark_files[0]  # older, newer


def compare_benchmarks(baseline_file: str, current_file: str):
    """Compare two benchmark files and show differences."""
    
    baseline = load_benchmark(baseline_file)
    current = load_benchmark(current_file)
    
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*70}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.BLUE}Performance Benchmark Comparison{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*70}{Colors.RESET}\n")
    
    print(f"Baseline: {Path(baseline_file).name}")
    print(f"Current:  {Path(current_file).name}\n")
    
    # Track statistics
    improvements = 0
    regressions = 0
    unchanged = 0
    
    for key in sorted(baseline.keys()):
        if key not in current:
            print(f"{Colors.YELLOW}⚠️  {key[0]} ({key[1]}): Not found in current benchmark{Colors.RESET}")
            continue
        
        b = baseline[key]
        c = current[key]
        
        operation, mode = key
        
        # Calculate percentage change
        duration_diff = ((c['mean_duration'] - b['mean_duration']) / b['mean_duration']) * 100
        memory_diff = ((c['mean_memory_mb'] - b['mean_memory_mb']) / b['mean_memory_mb']) * 100 if b['mean_memory_mb'] > 0 else 0
        
        # Determine status
        if duration_diff < -5:  # >5% faster
            status = f"{Colors.GREEN}🚀 FASTER{Colors.RESET}"
            improvements += 1
        elif duration_diff > 10:  # >10% slower
            status = f"{Colors.RED}🐌 SLOWER{Colors.RESET}"
            regressions += 1
        else:
            status = f"{Colors.YELLOW}➡️  STABLE{Colors.RESET}"
            unchanged += 1
        
        print(f"\n{status} - {operation} ({mode})")
        print(f"  Duration:")
        print(f"    Baseline: {b['mean_duration']:.3f}s ± {b['std_dev']:.3f}s")
        print(f"    Current:  {c['mean_duration']:.3f}s ± {c['std_dev']:.3f}s")
        print(f"    Change:   {duration_diff:+.1f}%")
        
        if abs(memory_diff) > 10:
            mem_status = "📈 More" if memory_diff > 0 else "📉 Less"
            print(f"  Memory:    {mem_status} ({memory_diff:+.1f}%)")
        
        if abs(c['success_rate'] - b['success_rate']) > 0.05:
            print(f"  Success:   {b['success_rate']*100:.0f}% → {c['success_rate']*100:.0f}%")
    
    # Summary
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*70}{Colors.RESET}")
    print(f"{Colors.BOLD}Summary:{Colors.RESET}")
    print(f"  {Colors.GREEN}🚀 Improvements: {improvements}{Colors.RESET}")
    print(f"  {Colors.YELLOW}➡️  Stable:       {unchanged}{Colors.RESET}")
    print(f"  {Colors.RED}🐌 Regressions:  {regressions}{Colors.RESET}")
    
    if regressions > 0:
        print(f"\n{Colors.RED}⚠️  Warning: Performance regressions detected!{Colors.RESET}")
        return 1
    elif improvements > 0:
        print(f"\n{Colors.GREEN}✅ Performance improvements detected!{Colors.RESET}")
        return 0
    else:
        print(f"\n{Colors.YELLOW}✅ Performance is stable{Colors.RESET}")
        return 0


def main():
    """Main entry point."""
    if len(sys.argv) == 3:
        baseline_file = sys.argv[1]
        current_file = sys.argv[2]
    elif len(sys.argv) == 1:
        print("Finding latest benchmark files...")
        baseline_file, current_file = find_latest_benchmarks()
        print(f"Comparing:\n  {baseline_file}\n  {current_file}\n")
    else:
        print("Usage:")
        print("  python compare_benchmarks.py baseline.json current.json")
        print("  python compare_benchmarks.py  # Uses latest two files")
        sys.exit(1)
    
    return compare_benchmarks(baseline_file, current_file)


if __name__ == "__main__":
    sys.exit(main())
