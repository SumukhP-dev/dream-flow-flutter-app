# Setting Up Supabase Credentials

The server requires Supabase credentials to start. Follow these steps:

## Quick Setup

1. **Get your Supabase credentials:**
   - Go to [Supabase Dashboard](https://app.supabase.com)
   - Select your project (or create a new one)
   - Navigate to **Settings** → **API**
   - Copy the following:
     - **Project URL** → `SUPABASE_URL`
     - **anon/public key** → `SUPABASE_ANON_KEY`
     - **service_role key** → `SUPABASE_SERVICE_ROLE_KEY` ⚠️ Keep this secret!

2. **Edit the `.env` file:**
   ```bash
   cd backend_fastapi
   nano .env  # or use your preferred editor
   ```

3. **Replace the placeholder values:**
   ```bash
   SUPABASE_URL=https://xxxxx.supabase.co
   SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

4. **Restart the server:**
   ```bash
   # Stop current server (if running)
   screen -S dreamflow-api -X quit
   
   # Start again
   ./run_server_persistent.sh --method screen
   ```

## Using Docker Compose (Alternative)

If you're using the Docker setup, Supabase is included and uses default keys. Check `docker-compose.yml` for the default values.

## Security Notes

- ⚠️ **Never commit `.env` file** to git
- ⚠️ **Never share** `SUPABASE_SERVICE_ROLE_KEY` publicly
- ✅ The `SUPABASE_ANON_KEY` is safe for client-side use
- ✅ The `SUPABASE_SERVICE_ROLE_KEY` should only be used server-side

## Testing

After setting up credentials, test the server:

```bash
# Check if server starts
screen -r dreamflow-api

# Test API (in another terminal)
curl http://localhost:8080/health
```

