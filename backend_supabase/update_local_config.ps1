# Update Supabase Configuration to Local Instance
# This script updates all .env files to use local Supabase

$localSupabaseEnv = Get-Content 'c:\Users\sumuk\OneDrive - Georgia Institute of Technology\Projects\Dream_Flow_Flutter_App\backend_supabase\local_supabase_env.txt' -Raw

# Extract values using regex
if ($localSupabaseEnv -match 'API_URL="([^"]+)"') {
    $apiUrl = $matches[1]
    Write-Host "API URL: $apiUrl"
}

if ($localSupabaseEnv -match 'ANON_KEY="([^"]+)"') {
    $anonKey = $matches[1]
    Write-Host "ANON_KEY extracted (length: $($anonKey.Length))"
}

if ($localSupabaseEnv -match 'SERVICE_ROLE_KEY="([^"]+)"') {
    $serviceRoleKey = $matches[1]
    Write-Host "SERVICE_ROLE_KEY extracted (length: $($serviceRoleKey.Length))"
}

# Update Flutter app .env.local
$flutterEnvPath = 'c:\Users\sumuk\OneDrive - Georgia Institute of Technology\Projects\Dream_Flow_Flutter_App\dream-flow-app\app\.env.local'
if (Test-Path $flutterEnvPath) {
    $content = Get-Content $flutterEnvPath -Raw
    $content = $content -replace 'SUPABASE_URL=https://dbpvmfglduprtbpaygmo\.supabase\.co', "SUPABASE_URL=$apiUrl"
    $content = $content -replace 'YOUR_SUPABASE_URL=https://dbpvmfglduprtbpaygmo\.supabase\.co', "YOUR_SUPABASE_URL=$apiUrl"
    $content = $content -replace 'SUPABASE_ANON_KEY=([^\r\n]+)', "SUPABASE_ANON_KEY=$anonKey"
    Set-Content $flutterEnvPath $content -NoNewline
    Write-Host "Updated: $flutterEnvPath"
}

# Update backend FastAPI .env
$backendEnvPath = 'c:\Users\sumuk\OneDrive - Georgia Institute of Technology\Projects\Dream_Flow_Flutter_App\backend_fastapi\.env'
if (Test-Path $backendEnvPath) {
    $content = Get-Content $backendEnvPath -Raw
    $content = $content -replace 'SUPABASE_URL=https://dbpvmfglduprtbpaygmo\.supabase\.co', "SUPABASE_URL=$apiUrl"
    $content = $content -replace 'YOUR_SUPABASE_URL=https://dbpvmfglduprtbpaygmo\.supabase\.co', "YOUR_SUPABASE_URL=$apiUrl"
    $content = $content -replace 'SUPABASE_ANON_KEY=([^\r\n]+)', "SUPABASE_ANON_KEY=$anonKey"
    $content = $content -replace 'SUPABASE_SERVICE_ROLE_KEY=([^\r\n]+)', "SUPABASE_SERVICE_ROLE_KEY=$serviceRoleKey"
    Set-Content $backendEnvPath $content -NoNewline
    Write-Host "Updated: $backendEnvPath"
}

Write-Host "`nConfiguration updated successfully!"
Write-Host "Local Supabase URL: $apiUrl"
Write-Host "Studio URL: http://127.0.0.1:54323"
