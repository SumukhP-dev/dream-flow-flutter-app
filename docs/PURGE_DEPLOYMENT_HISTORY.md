# Purging GitHub Deployment History

This guide explains how to purge all deployment history from your GitHub repository.

## What Gets Purged

1. **GitHub Deployments** - Created via GitHub Deployments API (can be deleted via API)
2. **GitHub Actions Workflow Runs** - Cannot be deleted via API, must be done manually
3. **GitHub Environments** - Can be deleted via API or GitHub web interface

## Method 1: Automated Script (Recommended)

### Prerequisites

1. **Create a GitHub Personal Access Token:**
   - Go to https://github.com/settings/tokens
   - Click "Generate new token (classic)"
   - Name it: "Purge Deployments"
   - Select scope: `repo` (Full control of private repositories)
   - Click "Generate token"
   - **Copy the token immediately** (you won't see it again)

### Windows (PowerShell)

```powershell
# Run the script with your token
.\scripts\purge_github_deployments.ps1 -GitHubToken YOUR_TOKEN_HERE
```

### Linux/Mac (Bash)

```bash
# Make script executable
chmod +x scripts/purge_github_deployments.sh

# Run the script with your token
./scripts/purge_github_deployments.sh YOUR_TOKEN_HERE
```

## Method 2: Manual Deletion via GitHub Web Interface

### Delete GitHub Actions Workflow Runs

1. Go to your repository: https://github.com/SumukhP-dev/Dream_Flow_Flutter_App
2. Click on the **"Actions"** tab
3. For each workflow:
   - Click on the workflow name (e.g., "Android Release", "iOS Release")
   - Click on individual workflow runs
   - Click the "..." menu (three dots) → **"Delete workflow run"**
   - Confirm deletion

**Note:** GitHub only allows deleting workflow runs one at a time. For bulk deletion, you may need to delete the workflow files entirely (see below).

### Delete Workflow Files (Removes All History)

If you want to remove all workflow history, you can delete the workflow files:

```bash
git rm .github/workflows/android-release.yml
git rm .github/workflows/ios-release.yml
git commit -m "Remove GitHub Actions workflows"
git push
```

**Warning:** This will delete the workflows entirely. You can always restore them later if needed.

### Delete GitHub Environments

1. Go to your repository
2. Click **Settings** → **Environments**
3. Delete any environments you don't need

## Method 3: Using GitHub CLI (if installed)

If you have GitHub CLI (`gh`) installed:

```bash
# Authenticate
gh auth login

# List deployments
gh api repos/SumukhP-dev/Dream_Flow_Flutter_App/deployments

# Delete deployments (replace DEPLOYMENT_ID)
gh api -X DELETE repos/SumukhP-dev/Dream_Flow_Flutter_App/deployments/DEPLOYMENT_ID

# List environments
gh api repos/SumukhP-dev/Dream_Flow_Flutter_App/environments

# Delete environment (replace ENV_NAME)
gh api -X DELETE repos/SumukhP-dev/Dream_Flow_Flutter_App/environments/ENV_NAME
```

## Verification

After purging, verify the cleanup:

1. **Check Deployments:**
   - Go to: https://github.com/SumukhP-dev/Dream_Flow_Flutter_App/deployments
   - Should show "No deployments found"

2. **Check Workflow Runs:**
   - Go to: https://github.com/SumukhP-dev/Dream_Flow_Flutter_App/actions
   - Should show no runs (if workflows were deleted) or empty history

3. **Check Environments:**
   - Go to: Settings → Environments
   - Should show no custom environments

## Important Notes

- **GitHub Actions workflow runs cannot be bulk-deleted via API** - they must be deleted manually or by removing the workflow files
- **Deleting workflow files removes all associated run history**
- **Deployment history is separate from workflow runs** - deployments are created via GitHub Deployments API
- **This action cannot be undone** - make sure you want to purge the history before proceeding

## Troubleshooting

### Script fails with "401 Unauthorized"
- Verify your GitHub token has the `repo` scope
- Make sure the token hasn't expired
- Check that you're using the correct repository owner/name

### Script fails with "404 Not Found"
- Verify the repository name and owner are correct
- Check that the repository exists and you have access

### Workflow runs still showing
- Workflow runs must be deleted manually via GitHub web interface
- Or delete the workflow files entirely to remove all history

