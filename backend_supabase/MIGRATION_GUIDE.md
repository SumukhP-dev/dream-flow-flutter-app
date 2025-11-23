# Supabase Migration Guide

This guide will help you check current tables and apply the migrations to your Supabase database.

## Prerequisites

1. **Supabase CLI** - Already set up (using npx)
2. **Supabase Project** - You need your project reference ID
3. **Access Token** - For authentication (optional, can use interactive login)

## Step 1: Authenticate with Supabase

You have two options:

### Option A: Interactive Login (Recommended)
```powershell
cd backend_supabase
npx supabase login
```
This will open a browser for authentication.

### Option B: Use Access Token
```powershell
$env:SUPABASE_ACCESS_TOKEN = "your_access_token_here"
```

You can get your access token from: https://supabase.com/dashboard/account/tokens

## Step 2: Link Your Project

Link your remote Supabase project:

```powershell
cd backend_supabase
npx supabase link --project-ref YOUR_PROJECT_REF
```

**To find your project reference:**
1. Go to your Supabase Dashboard
2. Select your project
3. Go to **Settings > General**
4. Copy the **Reference ID**

You'll be prompted for your database password during linking.

## Step 3: Check Current Tables

List all current tables in your database:

```powershell
npx supabase db remote list --schema public
```

Or to see tables in a specific format:

```powershell
npx supabase db remote list --schema public -o json
```

## Step 4: Check Migration Status

See which migrations have been applied:

```powershell
npx supabase migration list
```

## Step 5: Apply Migrations

Apply all pending migrations:

```powershell
npx supabase db push
```

This will:
- Apply migrations in order (by timestamp)
- Create the tables: `profiles`, `rituals`, `sessions`, `session_assets`
- Set up RLS policies
- Create indexes

## Step 6: Verify Tables Were Created

After applying migrations, verify the tables exist:

```powershell
npx supabase db remote list --schema public
```

You should see:
- `profiles`
- `rituals`
- `sessions`
- `session_assets`

## Alternative: Using Database URL Directly

If you have your database connection string, you can also use:

```powershell
npx supabase db remote list --db-url "postgresql://postgres:[PASSWORD]@[HOST]:5432/postgres"
```

## Troubleshooting

### Error: "Access token not provided"
- Run `npx supabase login` or set `SUPABASE_ACCESS_TOKEN` environment variable

### Error: "Project not linked"
- Run `npx supabase link --project-ref YOUR_PROJECT_REF`

### Error: "Migration already applied"
- This is normal if migrations were already run
- Check status with `npx supabase migration list`

### Error: "Permission denied"
- Ensure your access token has the correct permissions
- Check that you're using the correct project reference

## Migration Files

The following migrations will be applied in order:

1. `20240101000000_create_profiles.sql` - Creates profiles table
2. `20240101000001_create_rituals.sql` - Creates rituals table
3. `20240101000002_create_sessions.sql` - Creates sessions table
4. `20240101000003_create_session_assets.sql` - Creates session_assets table

## Quick Script

You can also use the provided PowerShell script:

```powershell
cd backend_supabase
.\apply_migrations.ps1
```

Make sure you're logged in and linked first!

