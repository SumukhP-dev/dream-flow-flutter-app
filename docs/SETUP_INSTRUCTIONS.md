# Setup Instructions

## Prerequisites

- Node.js >= 18.0.0
- pnpm >= 8.0.0

## Installation

1. Install pnpm if you haven't already:

```bash
npm install -g pnpm
```

2. Install all dependencies:

```bash
pnpm install
```

## Environment Variables

### Consumer App (dream-flow-web)

Create `apps/dream-flow-web/.env.local`:

```
NEXT_PUBLIC_SUPABASE_URL=your-supabase-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-supabase-anon-key
NEXT_PUBLIC_BACKEND_URL=http://localhost:8080
```

### Studio App (studio-web)

Create `apps/studio-web/.env.local`:

```
NEXT_PUBLIC_SUPABASE_URL=your-supabase-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-supabase-anon-key
NEXT_PUBLIC_BACKEND_URL=http://localhost:8080
```

## Running the Apps

### Development Mode

Run both apps simultaneously:

```bash
pnpm dev
```

Or run individually:

```bash
# Consumer app (port 3000)
cd apps/dream-flow-web
pnpm dev

# Studio app (port 3001)
cd apps/studio-web
pnpm dev
```

### Build

Build all apps:

```bash
pnpm build
```

## Common Issues

### TypeScript Errors

If you see TypeScript errors about missing types:

1. Make sure all packages are installed: `pnpm install`
2. Restart your TypeScript server in your IDE
3. Run type check: `pnpm type-check`

### Module Resolution Errors

If you see errors about `@dream-flow/*` packages:

1. Ensure you're using pnpm workspaces
2. Run `pnpm install` from the root directory
3. Check that `pnpm-workspace.yaml` is correct

### Supabase Auth Errors

If authentication isn't working:

1. Verify your Supabase URL and anon key in `.env.local`
2. Check that Supabase is properly configured
3. Ensure the backend is running and accessible

### API Connection Errors

If API calls fail:

1. Verify `NEXT_PUBLIC_BACKEND_URL` is correct
2. Ensure the FastAPI backend is running on the specified port
3. Check CORS settings in the backend

## Project Structure

```
dream-flow-monorepo/
├── apps/
│   ├── dream-flow-web/     # Consumer Next.js app (port 3000)
│   └── studio-web/         # Studio Next.js app (port 3001)
├── packages/
│   ├── design-system/      # Design tokens
│   ├── shared-ui/          # React components
│   ├── api-client/         # API clients
│   └── supabase-auth/      # Auth utilities
└── backend_fastapi/         # Existing FastAPI backend
```

## Next Steps

1. Configure environment variables
2. Start the FastAPI backend
3. Run `pnpm dev` to start both Next.js apps
4. Visit http://localhost:3000 for consumer app
5. Visit http://localhost:3001 for studio app
