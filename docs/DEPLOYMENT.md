# Deployment Guide

## Prerequisites

- Node.js >= 18.0.0
- pnpm >= 8.0.0
- Supabase account and project
- FastAPI backend deployed and accessible

## Environment Setup

### 1. Install Dependencies

```bash
pnpm install
```

### 2. Configure Environment Variables

**Consumer App** (`apps/dream-flow-web/.env.local`):

```
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
NEXT_PUBLIC_BACKEND_URL=https://your-backend-url.com
```

**Studio App** (`apps/studio-web/.env.local`):

```
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
NEXT_PUBLIC_BACKEND_URL=https://your-backend-url.com
```

## Building for Production

### Build All Apps

```bash
pnpm build
```

### Build Individual Apps

```bash
cd apps/dream-flow-web && pnpm build
cd apps/studio-web && pnpm build
```

## Deployment Options

### Vercel (Recommended)

1. **Connect Repository**

   - Import your Git repository to Vercel
   - Vercel will detect the monorepo structure

2. **Configure Projects**

   - Create separate projects for each app:
     - `dream-flow-web` (Root: `apps/dream-flow-web`)
     - `studio-web` (Root: `apps/studio-web`)

3. **Build Settings**

   - **Consumer App:**

     - Framework Preset: Next.js
     - Root Directory: `apps/dream-flow-web`
     - Build Command: `cd ../.. && pnpm build --filter=@dream-flow/web`
     - Output Directory: `.next`

   - **Studio App:**
     - Framework Preset: Next.js
     - Root Directory: `apps/studio-web`
     - Build Command: `cd ../.. && pnpm build --filter=@dream-flow/studio-web`
     - Output Directory: `.next`

4. **Environment Variables**
   - Add all environment variables in Vercel dashboard
   - Use the same variables as `.env.local`

### Other Platforms

#### Netlify

1. Install Netlify CLI: `npm install -g netlify-cli`
2. Configure `netlify.toml` for each app
3. Deploy: `netlify deploy --prod`

#### Self-Hosted

1. Build the apps: `pnpm build`
2. Start production servers:
   ```bash
   cd apps/dream-flow-web && pnpm start
   cd apps/studio-web && pnpm start
   ```
3. Use a reverse proxy (nginx) to route traffic

## Post-Deployment Checklist

- [ ] Verify environment variables are set correctly
- [ ] Test authentication flow (login/signup)
- [ ] Verify API connections to backend
- [ ] Test story generation
- [ ] Check video/audio playback
- [ ] Verify SEO metadata is working
- [ ] Test on mobile devices
- [ ] Check error tracking (Sentry)
- [ ] Verify analytics tracking

## Troubleshooting

### Build Errors

If you see module resolution errors:

1. Ensure all packages are installed: `pnpm install`
2. Check that workspace packages are properly linked
3. Verify TypeScript paths in `tsconfig.json`

### Runtime Errors

If apps fail to start:

1. Check environment variables are set
2. Verify Supabase connection
3. Check backend API is accessible
4. Review browser console for errors

### Authentication Issues

If auth isn't working:

1. Verify Supabase URL and anon key
2. Check CORS settings in Supabase
3. Ensure middleware is properly configured
4. Check browser console for auth errors

## Performance Optimization

### Already Implemented

- SSG for static pages
- ISR for story detail pages
- Package import optimization
- Image optimization (Next.js Image component)

### Additional Optimizations

1. **CDN Configuration**

   - Configure CDN for static assets
   - Set up CDN for video/audio files

2. **Caching**

   - Configure caching headers
   - Use service workers for offline support

3. **Bundle Analysis**
   - Run `pnpm build --analyze` to check bundle sizes
   - Optimize large dependencies

## Monitoring

### Error Tracking

Sentry is configured in both apps. Ensure `SENTRY_DSN` is set in production.

### Analytics

Consider adding:

- Google Analytics
- Plausible Analytics
- Custom analytics for story generation metrics

## Support

For issues or questions, refer to:

- `SETUP_INSTRUCTIONS.md` for development setup
- `README.md` for project overview
- Backend documentation for API details
