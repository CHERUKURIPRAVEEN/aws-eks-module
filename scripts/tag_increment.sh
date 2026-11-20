#!/usr/bin/env bash

set -euo pipefail

REMOTE="origin"

echo "========================================"
echo "Terraform Module Release"
echo "========================================"

# ------------------------------------------------------------
# Fetch all tags
# ------------------------------------------------------------

echo "Fetching latest tags..."

git fetch --tags --force "$REMOTE"

# ------------------------------------------------------------
# Find latest semantic version tag
# Expected format: vMAJOR.MINOR.PATCH
# ------------------------------------------------------------

LATEST_TAG=$(
    git tag --list 'v*.*.*' --sort=-v:refname |
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' |
    head -n1 || true
)

# ------------------------------------------------------------
# Calculate next version
# ------------------------------------------------------------

if [[ -z "$LATEST_TAG" ]]; then
    echo "No existing semantic version tags found."
    echo "Starting from v0.1.0"

    NEW_TAG="v0.1.0"
else
    echo "Latest tag: $LATEST_TAG"

    VERSION="${LATEST_TAG#v}"

    IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"

    # Increment MINOR version
    MINOR=$((MINOR + 1))
    PATCH=0

    NEW_TAG="v${MAJOR}.${MINOR}.${PATCH}"
fi

echo "Next release: $NEW_TAG"

# ------------------------------------------------------------
# Protect against duplicate tag
# ------------------------------------------------------------

if git ls-remote --exit-code --tags "$REMOTE" "refs/tags/$NEW_TAG" >/dev/null 2>&1; then
    echo "ERROR: Tag $NEW_TAG already exists on remote."
    exit 1
fi

# ------------------------------------------------------------
# Configure Git identity
# ------------------------------------------------------------

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

# ------------------------------------------------------------
# Create annotated tag
# ------------------------------------------------------------

echo "Creating annotated tag: $NEW_TAG"

git tag -a "$NEW_TAG" -m "Release $NEW_TAG"

# ------------------------------------------------------------
# Push tag using GitHub token
# ------------------------------------------------------------

echo "Pushing $NEW_TAG to $REMOTE..."

git push \
    "https://x-access-token:${PAT_TOKEN}@github.com/CHERUKURIPRAVEEN/aws-eks-module.git" \
    "$NEW_TAG"

echo "========================================"
echo "Successfully released $NEW_TAG"
echo "========================================"