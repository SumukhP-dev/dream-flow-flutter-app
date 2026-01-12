# Troubleshooting Guide

## Common Issues and Solutions

### Module Resolution Errors

**Error**: `Cannot find module '@dream-flow/design-system'`

**Solution**:

1. Run `pnpm install` from the root directory
2. Ensure `pnpm-workspace.yaml` is correctly configured
3. Check that package names in `package.json` match workspace references

### TypeScript Errors

**Error**: `Property 'X' does not exist on type 'Y'`

**Solution**:

1. Run `pnpm type-check` to see all TypeScript errors
2. Ensure all packages are built: `pnpm build`
3. Restart your TypeScript server in your IDE

### Build Failures

**Error**: `Error: Cannot find module` during build

**Solution**:

1. Clean build artifacts: `pnpm clean`
2. Reinstall dependencies: `rm -rf node_modules && pnpm install`
3. Rebuild packages: `pnpm build`

### Authentication Not Working

**Error**: `Unauthorized` or redirect loops

**Solution**:

1. Verify Supabase environment variables are set correctly
2. Check that `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` are correct
3. Ensure middleware is properly configured in both apps
4. Check browser console for specific error messages

### API Connection Errors

**Error**: `Failed to fetch` or CORS errors

**Solution**:

1. Verify `NEXT_PUBLIC_BACKEND_URL` is correct
2. Ensure FastAPI backend is running
3. Check CORS settings in FastAPI backend
4. Verify backend is accessible from your network

### Component Styling Issues

**Error**: Components don't match Flutter app design

**Solution**:

1. Verify design system package is properly imported
2. Check that design tokens are being used correctly
3. Ensure CSS is not being overridden by global styles

### Video/Audio Playback Issues

**Error**: Video/audio doesn't play

**Solution**:

1. Check that video/audio URLs are valid
2. Verify CORS settings allow video/audio playback
3. Check browser console for media errors
4. Ensure video/audio formats are supported by the browser

### Performance Issues

**Error**: Slow page loads or laggy interactions

**Solution**:

1. Check bundle sizes with `pnpm build --analyze`
2. Verify images are optimized
3. Check network tab for slow API calls
4. Consider implementing code splitting for large components

## Getting Help

If you encounter issues not covered here:

1. Check the browser console for error messages
2. Review server logs for backend errors
3. Check Supabase dashboard for auth issues
4. Review Next.js build output for warnings

## Development Tips

1. **Hot Reload**: Both apps support hot reload. Changes should appear immediately.
2. **Type Checking**: Run `pnpm type-check` regularly to catch type errors early.
3. **Linting**: Run `pnpm lint` to check code quality.
4. **Testing**: Test in both Chrome and Firefox to catch browser-specific issues.
