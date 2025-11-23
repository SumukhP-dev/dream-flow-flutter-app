# Analytics ETL Script

This document describes the ETL (Extract, Transform, Load) script for exporting Dream Flow analytics data from Supabase to CSV files for monetization tracking.

## Overview

The `etl_analytics_export.py` script exports daily analytics metrics including:
- **Daily Active Users (DAU)** - Count of unique users who created at least one session per day
- **Average Story Count** - Average number of stories per active user per day
- **Persona Mix** - Distribution of user personas across different segments

## Prerequisites

1. **Supabase Analytics Views**: The analytics views must be created in your Supabase database. Run the migration:
   ```bash
   # Apply the analytics views migration
   supabase migration up
   ```
   Or manually run: `backend_supabase/supabase/migrations/20240101000006_create_analytics_views.sql`

2. **Environment Variables**: The script requires the following environment variables:
   - `SUPABASE_URL` - Your Supabase project URL
   - `SUPABASE_SERVICE_ROLE_KEY` - Service role key for admin access (bypasses RLS)

3. **Python Dependencies**: All required packages are in `requirements.txt`:
   ```bash
   pip install -r requirements.txt
   ```

## Usage

### Basic Usage

Export analytics for the last 30 days (default):
```bash
python etl_analytics_export.py
```

### Custom Date Range

Export analytics for a specific date range:
```bash
python etl_analytics_export.py --start-date 2024-01-01 --end-date 2024-01-31
```

### Custom Output Directory

Specify a custom output directory:
```bash
python etl_analytics_export.py --output-dir /path/to/exports
```

### Complete Example

```bash
python etl_analytics_export.py \
  --start-date 2024-01-01 \
  --end-date 2024-01-31 \
  --output-dir ./analytics_exports
```

## Output Files

The script generates two CSV files:

### 1. Daily Metrics (`daily_metrics_YYYY-MM-DD_to_YYYY-MM-DD_TIMESTAMP.csv`)

Contains comprehensive daily metrics with the following columns:

| Column | Description |
|--------|-------------|
| `date` | Date (YYYY-MM-DD) |
| `daily_active_users` | Number of unique users active on this day |
| `total_stories` | Total number of stories created on this day |
| `avg_stories_per_user` | Average stories per active user |
| `active_users` | Number of active users (same as DAU) |
| `unique_themes` | Number of unique themes used |
| `avg_target_length` | Average target story length |
| `avg_num_scenes` | Average number of scenes per story |
| `{persona}_user_count` | Number of users in each persona segment |
| `{persona}_story_count` | Number of stories created by each persona |
| `{persona}_user_percentage` | Percentage of users in each persona segment |

### 2. Persona Mix (`persona_mix_YYYY-MM-DD_to_YYYY-MM-DD_TIMESTAMP.csv`)

Contains detailed persona distribution per day:

| Column | Description |
|--------|-------------|
| `date` | Date (YYYY-MM-DD) |
| `persona` | Persona type (mindful_professional, burned_out_parent, wellness_seeker, unknown) |
| `user_count` | Number of users in this persona on this day |
| `story_count` | Number of stories created by this persona on this day |
| `user_percentage` | Percentage of total users represented by this persona |

## Persona Classification

Users are automatically classified into personas based on their profile data and behavior:

### Mindful Professional
- High session count (≥5 sessions)
- Profile contains professional/work-related keywords in `routine` field
- Mood indicates stress, focus, or calm

### Burned Out Parent
- Profile mentions kids, children, family, or bedtime routines
- Preferences or routine fields contain parenting-related keywords

### Wellness Seeker
- Multiple calming elements (>2)
- Preferences mention ASMR, meditation, wellness, or sensory elements
- Calming elements include ASMR, binaural, ambient, or sensory keywords

### Unknown
- Default classification when no clear pattern matches

## Analytics Views

The script queries the following Supabase views:

- `analytics_daily_comprehensive` - Main view combining all daily metrics
- `analytics_daily_persona_mix` - Detailed persona distribution per day

These views are created by the migration `20240101000006_create_analytics_views.sql`.

## Scheduling

For regular exports, you can schedule this script using:

### Cron (Linux/Mac)
```bash
# Export daily at 2 AM
0 2 * * * cd /path/to/backend_fastapi && python etl_analytics_export.py --start-date $(date -d "yesterday" +\%Y-\%m-\%d) --end-date $(date -d "yesterday" +\%Y-\%m-\%d)
```

### Windows Task Scheduler
Create a scheduled task that runs:
```powershell
python C:\path\to\backend_fastapi\etl_analytics_export.py --start-date 2024-01-01 --end-date 2024-01-31
```

### GitHub Actions / CI/CD
Add to your workflow:
```yaml
- name: Export Analytics
  run: |
    cd backend_fastapi
    python etl_analytics_export.py --start-date ${{ github.event.inputs.start_date }} --end-date ${{ github.event.inputs.end_date }}
  env:
    SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
    SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
```

## Error Handling

The script will:
- Exit with error code 1 if Supabase connection fails
- Exit with error code 1 if required environment variables are missing
- Print helpful error messages to stderr
- Create output directory if it doesn't exist

## Security Notes

- The script uses the `SUPABASE_SERVICE_ROLE_KEY` which bypasses Row Level Security (RLS)
- This key should **never** be committed to version control
- Store it securely in environment variables or secrets management
- The analytics views are read-only and safe for export

## Troubleshooting

### No data exported
- Verify the date range contains data in the `sessions` table
- Check that the analytics views exist: `SELECT * FROM analytics_daily_comprehensive LIMIT 1;`
- Ensure the migration has been applied

### Connection errors
- Verify `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are set correctly
- Check network connectivity to Supabase
- Verify the service role key has not expired

### Permission errors
- Ensure the service role key has SELECT permissions on the analytics views
- Check that the views were created with proper GRANT statements

## Example Output

```
Exporting analytics from 2024-01-01 to 2024-01-31
Exported 31 daily metrics records to analytics_exports/daily_metrics_2024-01-01_to_2024-01-31_20240115_143022.csv
Exported 124 persona mix records to analytics_exports/persona_mix_2024-01-01_to_2024-01-31_20240115_143022.csv

All analytics exported to analytics_exports
```

