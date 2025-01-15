#!/usr/bin/env bash

# Enable debug mode
set -x

# Ensure all required variables are set
: "${1:?Missing UPSTREAM_REPO}"
: "${2:?Missing UPSTREAM_BRANCH}"
: "${3:?Missing DOWNSTREAM_BRANCH}"
: "${4:?Missing CUSTOM_TOKEN}"

# Assign inputs to variables
UPSTREAM_REPO="$1"
UPSTREAM_BRANCH="$2"
DOWNSTREAM_BRANCH="$3"
CUSTOM_TOKEN="$4"
FETCH_ARGS="${5:-}"
MERGE_ARGS="${6:-}"
PUSH_ARGS="${7:-}"
SPAWN_LOGS="${8:-false}"

echo "Using UPSTREAM_REPO: $UPSTREAM_REPO"
echo "Using UPSTREAM_BRANCH: $UPSTREAM_BRANCH"
echo "Using DOWNSTREAM_BRANCH: $DOWNSTREAM_BRANCH"

# Clone the downstream repository
git clone "https://x-access-token:${CUSTOM_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" work || {
  echo "Failed to clone repository"
  exit 1
}
cd work || { echo "Failed to enter work directory"; exit 2; }

# Configure git user
git config user.name "${GITHUB_ACTOR}"
git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"

# Add and fetch the upstream repository
if [[ ! "$UPSTREAM_REPO" =~ \.git$ ]]; then
  UPSTREAM_REPO="https://github.com/${UPSTREAM_REPO}.git"
fi
git remote add upstream "$UPSTREAM_REPO" || { echo "Failed to add upstream"; exit 3; }
git fetch ${FETCH_ARGS} upstream || { echo "Failed to fetch upstream"; exit 4; }

# Checkout the downstream branch
git checkout "${DOWNSTREAM_BRANCH}" || { echo "Failed to checkout branch ${DOWNSTREAM_BRANCH}"; exit 5; }

# Spawn logs if enabled
if [[ "$SPAWN_LOGS" == "true" ]]; then
  echo "Syncing upstream at $(date)" > sync-upstream-log.txt
  git add sync-upstream-log.txt
  git commit -m "Added sync log"
fi

# Merge upstream changes
MERGE_RESULT=$(git merge ${MERGE_ARGS} upstream/"${UPSTREAM_BRANCH}" 2>&1)

if [[ $? -ne 0 ]]; then
  echo "Merge failed: $MERGE_RESULT"
  exit 6
elif [[ "$MERGE_RESULT" != *"Already up to date."* ]]; then
  # Commit and push changes
  git commit -m "Merged upstream changes" || echo "Nothing to commit, already up to date."
  git push ${PUSH_ARGS} origin "${DOWNSTREAM_BRANCH}" || { echo "Push failed"; exit 7; }
else
  echo "Already up to date with upstream."
fi

# Cleanup
cd ..
rm -rf work
echo "Sync complete."
