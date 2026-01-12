"""
Track test history from GitHub Actions.

Fetches test run history and generates reports/visualizations.

Usage:
    python track_test_history.py
    python track_test_history.py --days 30
    python track_test_history.py --export csv
"""

import os
import sys
import json
import argparse
from datetime import datetime, timedelta
from pathlib import Path

try:
    import requests
except ImportError:
    print("❌ requests not installed. Run: pip install requests")
    sys.exit(1)


class TestHistoryTracker:
    """Track test history from GitHub Actions."""
    
    def __init__(self, repo: str, token: str = None):
        self.repo = repo
        self.token = token or os.getenv('GITHUB_TOKEN')
        self.workflow_name = "inference-tests.yml"
        
        if not self.token:
            print("⚠️  GITHUB_TOKEN not set. Rate limits will be lower.")
            print("   Set with: export GITHUB_TOKEN=your_token")
        
        self.headers = {
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28"
        }
        if self.token:
            self.headers["Authorization"] = f"Bearer {self.token}"
    
    def fetch_workflow_runs(self, days: int = 30) -> list:
        """Fetch workflow runs from last N days."""
        url = f"https://api.github.com/repos/{self.repo}/actions/workflows/{self.workflow_name}/runs"
        
        created_after = (datetime.now() - timedelta(days=days)).isoformat()
        params = {
            "per_page": 100,
            "created": f">{created_after}"
        }
        
        print(f"Fetching workflow runs from last {days} days...")
        
        try:
            response = requests.get(url, headers=self.headers, params=params)
            response.raise_for_status()
            
            runs = response.json()["workflow_runs"]
            print(f"✅ Found {len(runs)} workflow runs")
            return runs
        
        except requests.exceptions.RequestException as e:
            print(f"❌ Error fetching runs: {e}")
            sys.exit(1)
    
    def process_runs(self, runs: list) -> list:
        """Process runs into structured data."""
        history = []
        
        for run in runs:
            # Calculate duration
            created = datetime.fromisoformat(run["created_at"].replace('Z', '+00:00'))
            updated = datetime.fromisoformat(run["updated_at"].replace('Z', '+00:00'))
            duration = (updated - created).total_seconds()
            
            history.append({
                "id": run["id"],
                "date": run["created_at"],
                "status": run["conclusion"],
                "duration_seconds": duration,
                "commit_sha": run["head_sha"][:7],
                "commit_message": run["head_commit"]["message"].split('\n')[0][:80],
                "branch": run["head_branch"],
                "url": run["html_url"]
            })
        
        return history
    
    def print_summary(self, history: list):
        """Print summary of test runs."""
        print(f"\n{'='*80}")
        print("Test History Summary")
        print(f"{'='*80}\n")
        
        total = len(history)
        passed = sum(1 for h in history if h["status"] == "success")
        failed = sum(1 for h in history if h["status"] == "failure")
        cancelled = sum(1 for h in history if h["status"] == "cancelled")
        
        pass_rate = (passed / total * 100) if total > 0 else 0
        avg_duration = sum(h["duration_seconds"] for h in history) / len(history)
        
        print(f"Total Runs:    {total}")
        print(f"✅ Passed:      {passed} ({pass_rate:.1f}%)")
        print(f"❌ Failed:      {failed}")
        print(f"🚫 Cancelled:   {cancelled}")
        print(f"⏱️  Avg Duration: {avg_duration:.1f}s\n")
        
        # Recent runs
        print("Recent Runs:")
        print("-" * 80)
        for run in history[:10]:
            status_icon = {
                "success": "✅",
                "failure": "❌",
                "cancelled": "🚫"
            }.get(run["status"], "❓")
            
            date = datetime.fromisoformat(run["date"].replace('Z', '+00:00'))
            print(f"{status_icon} {date.strftime('%Y-%m-%d %H:%M')} "
                  f"[{run['commit_sha']}] {run['commit_message']}")
    
    def export_to_csv(self, history: list, filename: str = "test_history.csv"):
        """Export history to CSV."""
        try:
            import csv
            
            filepath = Path(__file__).parent / "performance_results" / filename
            filepath.parent.mkdir(exist_ok=True)
            
            with open(filepath, 'w', newline='') as f:
                if history:
                    writer = csv.DictWriter(f, fieldnames=history[0].keys())
                    writer.writeheader()
                    writer.writerows(history)
            
            print(f"✅ Exported to {filepath}")
        
        except ImportError:
            print("❌ csv module not available")
    
    def export_to_json(self, history: list, filename: str = "test_history.json"):
        """Export history to JSON."""
        filepath = Path(__file__).parent / "performance_results" / filename
        filepath.parent.mkdir(exist_ok=True)
        
        with open(filepath, 'w') as f:
            json.dump(history, f, indent=2)
        
        print(f"✅ Exported to {filepath}")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Track test history from GitHub Actions"
    )
    parser.add_argument(
        '--repo',
        default=os.getenv('GITHUB_REPOSITORY', 'your-username/Dream_Flow_Flutter_App'),
        help='GitHub repository (owner/name)'
    )
    parser.add_argument(
        '--days',
        type=int,
        default=30,
        help='Number of days of history to fetch'
    )
    parser.add_argument(
        '--export',
        choices=['csv', 'json', 'both'],
        default='both',
        help='Export format'
    )
    
    args = parser.parse_args()
    
    tracker = TestHistoryTracker(args.repo)
    runs = tracker.fetch_workflow_runs(args.days)
    history = tracker.process_runs(runs)
    
    tracker.print_summary(history)
    
    if args.export in ['csv', 'both']:
        tracker.export_to_csv(history)
    
    if args.export in ['json', 'both']:
        tracker.export_to_json(history)
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
