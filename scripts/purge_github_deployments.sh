#!/bin/bash
# Script to purge GitHub deployment history
# Requires GitHub Personal Access Token with repo scope

set -e

GITHUB_TOKEN="${1:-}"
OWNER="${2:-SumukhP-dev}"
REPO="${3:-Dream_Flow_Flutter_App}"

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Usage: $0 <GITHUB_TOKEN> [OWNER] [REPO]"
    echo ""
    echo "To create a GitHub Personal Access Token:"
    echo "1. Go to https://github.com/settings/tokens"
    echo "2. Click 'Generate new token (classic)'"
    echo "3. Select 'repo' scope"
    echo "4. Copy the token and use it as the first argument"
    exit 1
fi

BASE_URL="https://api.github.com/repos/$OWNER/$REPO"
AUTH_HEADER="Authorization: token $GITHUB_TOKEN"

echo "Fetching deployments for $OWNER/$REPO..."

# Get all deployments
DEPLOYMENTS=$(curl -s -H "$AUTH_HEADER" \
    -H "Accept: application/vnd.github.v3+json" \
    "$BASE_URL/deployments")

DEPLOYMENT_COUNT=$(echo "$DEPLOYMENTS" | jq '. | length' 2>/dev/null || echo "0")

if [ "$DEPLOYMENT_COUNT" -eq 0 ]; then
    echo "No deployments found. Nothing to purge."
    exit 0
fi

echo "Found $DEPLOYMENT_COUNT deployments"

# Delete each deployment
echo "$DEPLOYMENTS" | jq -r '.[] | "\(.id)|\(.environment)|\(.ref)"' | while IFS='|' read -r id environment ref; do
    echo "Deleting deployment $id (Environment: $environment, Ref: $ref)..."
    
    if curl -s -X DELETE \
        -H "$AUTH_HEADER" \
        -H "Accept: application/vnd.github.v3+json" \
        "$BASE_URL/deployments/$id" > /dev/null; then
        echo "  ✓ Deleted deployment $id"
    else
        echo "  ✗ Failed to delete deployment $id"
    fi
done

echo ""
echo "Deployment purge complete!"
echo ""
echo "Note: GitHub Actions workflow runs cannot be deleted via API."
echo "To delete workflow runs, go to:"
echo "  https://github.com/$OWNER/$REPO/actions"
echo "And manually delete runs, or delete the workflow files entirely."

