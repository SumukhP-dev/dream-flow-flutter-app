#!/usr/bin/env python3
"""
ETL Script for Dream Flow Analytics Export

This script exports daily analytics from Supabase to CSV for monetization tracking.
Metrics include:
- Daily Active Users (DAU)
- Average story count per user
- Persona mix distribution

Usage:
    python etl_analytics_export.py [--start-date YYYY-MM-DD] [--end-date YYYY-MM-DD] [--output-dir OUTPUT_DIR]
"""

import argparse
import csv
import json
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

from supabase import create_client
from supabase.lib.client_options import ClientOptions

# Add parent directory to path to import config
sys.path.insert(0, str(Path(__file__).parent))

from app.config import Settings, get_settings


class AnalyticsETL:
    """ETL class for exporting analytics data from Supabase to CSV."""

    def __init__(self, settings: Settings):
        """
        Initialize the ETL with Supabase connection.

        Args:
            settings: Settings instance with Supabase configuration
        """
        if not settings.supabase_url:
            raise ValueError("SUPABASE_URL environment variable is required")
        if not settings.supabase_service_role_key:
            raise ValueError("SUPABASE_SERVICE_ROLE_KEY environment variable is required")

        self.client = create_client(
            settings.supabase_url,
            settings.supabase_service_role_key,
            options=ClientOptions(
                auto_refresh_token=False,
                persist_session=False,
            ),
        )
        self.settings = settings

    def fetch_daily_analytics(
        self, start_date: datetime | None = None, end_date: datetime | None = None
    ) -> list[dict[str, Any]]:
        """
        Fetch daily analytics data from the comprehensive view.

        Args:
            start_date: Optional start date filter (inclusive)
            end_date: Optional end date filter (inclusive)

        Returns:
            List of daily analytics records
        """
        query = self.client.table("analytics_daily_comprehensive").select("*")

        if start_date:
            query = query.gte("date", start_date.date().isoformat())
        if end_date:
            query = query.lte("date", end_date.date().isoformat())

        query = query.order("date", desc=False)

        response = query.execute()
        return response.data if response.data else []

    def fetch_persona_mix(self, start_date: datetime | None = None, end_date: datetime | None = None) -> list[dict[str, Any]]:
        """
        Fetch daily persona mix data.

        Args:
            start_date: Optional start date filter (inclusive)
            end_date: Optional end date filter (inclusive)

        Returns:
            List of persona mix records
        """
        query = self.client.table("analytics_daily_persona_mix").select("*")

        if start_date:
            query = query.gte("date", start_date.date().isoformat())
        if end_date:
            query = query.lte("date", end_date.date().isoformat())

        query = query.order("date", desc=False).order("persona", desc=False)

        response = query.execute()
        return response.data if response.data else []

    def export_daily_metrics_to_csv(
        self,
        output_path: Path,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
    ) -> None:
        """
        Export daily metrics to CSV file.

        Args:
            output_path: Path to output CSV file
            start_date: Optional start date filter
            end_date: Optional end date filter
        """
        data = self.fetch_daily_analytics(start_date, end_date)

        if not data:
            print(f"No data found for the specified date range.")
            return

        # Flatten persona_mix JSON for CSV export
        csv_rows = []
        for record in data:
            row = {
                "date": record.get("date"),
                "daily_active_users": record.get("daily_active_users", 0),
                "total_stories": record.get("total_stories", 0),
                "avg_stories_per_user": record.get("avg_stories_per_user", 0),
                "active_users": record.get("active_users", 0),
                "unique_themes": record.get("unique_themes", 0),
                "avg_target_length": record.get("avg_target_length", 0),
                "avg_num_scenes": record.get("avg_num_scenes", 0),
            }

            # Extract persona mix data
            persona_mix = record.get("persona_mix", {})
            if isinstance(persona_mix, str):
                persona_mix = json.loads(persona_mix)

            # Add persona columns
            personas = ["mindful_professional", "burned_out_parent", "wellness_seeker", "unknown"]
            for persona in personas:
                persona_data = persona_mix.get(persona, {})
                row[f"{persona}_user_count"] = persona_data.get("user_count", 0)
                row[f"{persona}_story_count"] = persona_data.get("story_count", 0)
                row[f"{persona}_user_percentage"] = persona_data.get("user_percentage", 0.0)

            csv_rows.append(row)

        # Write to CSV
        if csv_rows:
            fieldnames = [
                "date",
                "daily_active_users",
                "total_stories",
                "avg_stories_per_user",
                "active_users",
                "unique_themes",
                "avg_target_length",
                "avg_num_scenes",
                "mindful_professional_user_count",
                "mindful_professional_story_count",
                "mindful_professional_user_percentage",
                "burned_out_parent_user_count",
                "burned_out_parent_story_count",
                "burned_out_parent_user_percentage",
                "wellness_seeker_user_count",
                "wellness_seeker_story_count",
                "wellness_seeker_user_percentage",
                "unknown_user_count",
                "unknown_story_count",
                "unknown_user_percentage",
            ]

            with open(output_path, "w", newline="", encoding="utf-8") as f:
                writer = csv.DictWriter(f, fieldnames=fieldnames)
                writer.writeheader()
                writer.writerows(csv_rows)

            print(f"Exported {len(csv_rows)} daily metrics records to {output_path}")
        else:
            print("No data to export.")

    def export_persona_mix_to_csv(
        self,
        output_path: Path,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
    ) -> None:
        """
        Export persona mix data to CSV file.

        Args:
            output_path: Path to output CSV file
            start_date: Optional start date filter
            end_date: Optional end date filter
        """
        data = self.fetch_persona_mix(start_date, end_date)

        if not data:
            print(f"No persona mix data found for the specified date range.")
            return

        fieldnames = ["date", "persona", "user_count", "story_count", "user_percentage"]

        with open(output_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(data)

        print(f"Exported {len(data)} persona mix records to {output_path}")

    def export_all(
        self,
        output_dir: Path,
        start_date: datetime | None = None,
        end_date: datetime | None = None,
    ) -> None:
        """
        Export all analytics data to CSV files.

        Args:
            output_dir: Directory to save CSV files
            start_date: Optional start date filter
            end_date: Optional end date filter
        """
        output_dir.mkdir(parents=True, exist_ok=True)

        # Generate filename with date range
        date_suffix = ""
        if start_date and end_date:
            date_suffix = f"_{start_date.date()}_to_{end_date.date()}"
        elif start_date:
            date_suffix = f"_{start_date.date()}_onwards"
        elif end_date:
            date_suffix = f"_until_{end_date.date()}"

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        # Export daily metrics
        daily_metrics_path = output_dir / f"daily_metrics{date_suffix}_{timestamp}.csv"
        self.export_daily_metrics_to_csv(daily_metrics_path, start_date, end_date)

        # Export persona mix
        persona_mix_path = output_dir / f"persona_mix{date_suffix}_{timestamp}.csv"
        self.export_persona_mix_to_csv(persona_mix_path, start_date, end_date)

        print(f"\nAll analytics exported to {output_dir}")


def parse_date(date_str: str) -> datetime:
    """Parse date string in YYYY-MM-DD format."""
    try:
        return datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError:
        raise argparse.ArgumentTypeError(f"Invalid date format: {date_str}. Use YYYY-MM-DD")


def main():
    """Main entry point for the ETL script."""
    parser = argparse.ArgumentParser(
        description="Export Dream Flow analytics from Supabase to CSV for monetization tracking"
    )
    parser.add_argument(
        "--start-date",
        type=parse_date,
        help="Start date for data export (YYYY-MM-DD). Defaults to 30 days ago.",
    )
    parser.add_argument(
        "--end-date",
        type=parse_date,
        help="End date for data export (YYYY-MM-DD). Defaults to today.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).parent / "analytics_exports",
        help="Directory to save CSV files. Defaults to analytics_exports/",
    )

    args = parser.parse_args()

    # Set default dates if not provided
    end_date = args.end_date or datetime.now()
    start_date = args.start_date or (end_date - timedelta(days=30))

    if start_date > end_date:
        print("Error: Start date must be before or equal to end date.")
        sys.exit(1)

    try:
        settings = get_settings()
        etl = AnalyticsETL(settings)

        print(f"Exporting analytics from {start_date.date()} to {end_date.date()}")
        etl.export_all(args.output_dir, start_date, end_date)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

