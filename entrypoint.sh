#!/usr/bin/env bash

# Enable debug mode
set -x

# Ensure necessary environment variables are set
: "${UPSTREAM_REPO:?Missing UPSTREAM_REPO}"
: "${UPSTREAM_BRANCH:?Missing UPSTREAM_BRANCH}"
: "${DOWNSTREAM_BRANCH:?Missing DOWNSTREAM_BRANCH}"
: "${CUSTOM_TOKEN:?Missing CUSTOM_TOKEN}"
: "${GITHUB_REPOSITORY:?Missing GITHUB_REPOSITORY}"

# Optional args with default values
FETCH_ARGS="${FETCH_ARGS:-}"
MERGE_ARGS="${MERGE_ARGS:-}"
PUSH_ARGS="${PUSH_ARGS:-}"
SPAWN_LOGS="${SPAWN_LOGS:-false}"

# If UPSTREAM_REPO is not a full URL, add GitHub default
if [[ ! "$UPSTREAM_REPO" =~ \.git$ ]]; then
  UPSTREAM_REPO="https://github.com/${UPSTREAM_REPO}.git"
fi

echo "Using UPSTREAM_REPO=$UPSTREAM_REPO"

# Clone the downstream repository
git clone "https://github.com/${GITHUB_REPOSITORY}.git" work
cd work || { echo "Failed to enter work directory" && exit 2; }

# Set GitHub user credentials for authentication
git config user.name "${GITHUB_ACTOR}"
git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"
git config --local user.password "${CUSTOM_TOKEN}"

# Set remote URL for pushing changes
git remote set-url origin "https://x-access-token:${CUSTOM_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

# Add upstream remote and fetch changes
git remote add upstream "$UPSTREAM_REPO"
git fetch ${FETCH_ARGS} upstream

# Show current remotes
git remote -v

# Switch to the target downstream branch
git checkout "${DOWNSTREAM_BRANCH}" || { echo "Failed to checkout ${DOWNSTREAM_BRANCH}" && exit 3; }

# Handle log spawning if required
if [[ "$SPAWN_LOGS" == "true" ]]; then
  echo "Syncing upstream repo: $UPSTREAM_REPO" > sync-upstream-repo.log
  echo "Sync time: $(date)" >> sync-upstream-repo.log
  git add sync-upstream-repo.log
  git commit -m "Sync upstream repo logs"
fi

# Merge upstream changes into the downstream branch
MERGE_RESULT=$(git merge ${MERGE_ARGS} upstream/${UPSTREAM_BRANCH} 2>&1)

# Check if the merge was successful
if [[ $? -ne 0 ]]; then
  echo "Merge failed: $MERGE_RESULT"
  exit 4
elif [[ "$MERGE_RESULT" != *"Already up to date."* ]]; then
  # Commit merge changes if necessary
  git commit -m "Merged upstream changes"
  git push ${PUSH_ARGS} origin "${DOWNSTREAM_BRANCH}" || { echo "Push failed"; exit 5; }
else
  echo "Already up to date with upstream."
fi

# Clean up by removing the temporary 'work' directory
cd ..
rm -rf work

echo "Sync complete."
