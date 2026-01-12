# Flutter Web Run Script with Supabase Configuration
# This script runs the Flutter app on Chrome with proper --dart-define arguments
# since Flutter Web doesn't load .env files (only --dart-define works)

Write-Host "🚀 Starting Flutter Web with Supabase configuration..." -ForegroundColor Green

# Supabase Configuration
$SUPABASE_URL = "https://dbpvmfglduprtbpaygmo.supabase.co"
$SUPABASE_ANON_KEY = "sb_publishable_s1LUGs4Go22G_Z1y7WnQJw_nKcU5pZy"

# Run Flutter with dart-define arguments
flutter run -d chrome `
  --dart-define=SUPABASE_URL=$SUPABASE_URL `
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY `
  --dart-define=ENVIRONMENT=development

Write-Host "✅ Flutter Web started with Supabase configuration" -ForegroundColor Green