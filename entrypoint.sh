#!/usr/bin/env bash

# Enable exit on error
set -e

# Function to print info messages in green
info() {
  echo -e "\033[32m[INFO] $1\033[0m"  # Green color for INFO
}

# Function to print error messages in red
error() {
  echo -e "\033[31m[ERROR] $1\033[0m"  # Red color for ERROR
}

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

info "Using UPSTREAM_REPO: $UPSTREAM_REPO"
info "Using UPSTREAM_BRANCH: $UPSTREAM_BRANCH"
info "Using DOWNSTREAM_BRANCH: $DOWNSTREAM_BRANCH"

# Clone the downstream repository
info "Cloning the downstream repository"
git clone "https://x-access-token:${CUSTOM_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" work
cd work

# Configure git user
info "Configuring git user"
git config user.name "${GITHUB_ACTOR}"
git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"

# Add and fetch the upstream repository
info "Adding upstream remote"
if [[ ! "$UPSTREAM_REPO" =~ \.git$ ]]; then
  UPSTREAM_REPO="https://github.com/${UPSTREAM_REPO}.git"
fi
git remote add upstream "$UPSTREAM_REPO"
info "Fetching upstream repository"
git fetch ${FETCH_ARGS} upstream

# Checkout the downstream branch
info "Checking out downstream branch"
git checkout "${DOWNSTREAM_BRANCH}"

# Spawn logs if enabled
if [[ "$SPAWN_LOGS" == "true" ]]; then
  info "Syncing upstream at $(date)" > sync-upstream-log.txt
  git add sync-upstream-log.txt
  git commit -m "Added sync log"
fi

# Merge upstream changes
info "Merging upstream changes"
MERGE_RESULT=$(git merge ${MERGE_ARGS} upstream/"${UPSTREAM_BRANCH}" 2>&1)

if [[ $? -ne 0 ]]; then
  error "Merge failed: $MERGE_RESULT"
  exit 6
elif [[ "$MERGE_RESULT" != *"Already up to date."* ]]; then
  # Commit and push changes
  info "Committing merged changes"
  git commit -m "Merged upstream changes" || info "Nothing to commit, already up to date."
  info "Pushing changes to downstream repository"
  git push ${PUSH_ARGS} origin "${DOWNSTREAM_BRANCH}"
else
  info "Already up to date with upstream."
fi

# Cleanup
cd ..
info "Cleaning up"
rm -rf work
info "Sync complete."
