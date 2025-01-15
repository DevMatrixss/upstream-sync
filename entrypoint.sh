#!/usr/bin/env bash

set -x

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

: "${1:?Missing UPSTREAM_REPO}"
: "${2:?Missing UPSTREAM_BRANCH}"
: "${3:?Missing DOWNSTREAM_BRANCH}"
: "${4:?Missing CUSTOM_TOKEN}"

UPSTREAM_REPO="$1"
UPSTREAM_BRANCH="$2"
DOWNSTREAM_BRANCH="$3"
CUSTOM_TOKEN="$4"
FETCH_ARGS="${5:-}"
MERGE_ARGS="${6:-}"
PUSH_ARGS="${7:-}"
SPAWN_LOGS="${8:-false}"

echo -e "${CYAN}Using UPSTREAM_REPO: $UPSTREAM_REPO${RESET}"
echo -e "${CYAN}Using UPSTREAM_BRANCH: $UPSTREAM_BRANCH${RESET}"
echo -e "${CYAN}Using DOWNSTREAM_BRANCH: $DOWNSTREAM_BRANCH${RESET}"

echo -e "${YELLOW}Cloning downstream repository...${RESET}"
git clone "https://x-access-token:${CUSTOM_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" work || {
  echo -e "${RED}Failed to clone repository${RESET}"
  exit 1
}
cd work || { echo -e "${RED}Failed to enter work directory${RESET}"; exit 2; }

echo -e "${YELLOW}Configuring git user...${RESET}"
git config user.name "${GITHUB_ACTOR}"
git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"

if [[ ! "$UPSTREAM_REPO" =~ \.git$ ]]; then
  UPSTREAM_REPO="https://github.com/${UPSTREAM_REPO}.git"
fi
echo -e "${YELLOW}Adding upstream remote...${RESET}"
git remote add upstream "$UPSTREAM_REPO" || { echo -e "${RED}Failed to add upstream${RESET}"; exit 3; }
echo -e "${YELLOW}Fetching upstream...${RESET}"
git fetch ${FETCH_ARGS} upstream || { echo -e "${RED}Failed to fetch upstream${RESET}"; exit 4; }

echo -e "${YELLOW}Checking out downstream branch: ${DOWNSTREAM_BRANCH}...${RESET}"
git checkout "${DOWNSTREAM_BRANCH}" || { echo -e "${RED}Failed to checkout branch ${DOWNSTREAM_BRANCH}${RESET}"; exit 5; }

if [[ "$SPAWN_LOGS" == "true" ]]; then
  echo "Syncing upstream at $(date)" > sync-upstream-log.txt
  git add sync-upstream-log.txt
  git commit -m "Added sync log"
fi

echo -e "${YELLOW}Merging upstream changes...${RESET}"
MERGE_RESULT=$(git merge ${MERGE_ARGS} upstream/"${UPSTREAM_BRANCH}" 2>&1)

if [[ $? -ne 0 ]]; then
  echo -e "${RED}Merge failed: $MERGE_RESULT${RESET}"
  exit 6
elif [[ "$MERGE_RESULT" != *"Already up to date."* ]]; then
  echo -e "${GREEN}Committing merged changes...${RESET}"
  git commit -m "Merged upstream changes" || echo -e "${YELLOW}Nothing to commit, already up to date.${RESET}"
  echo -e "${GREEN}Pushing changes to origin...${RESET}"
  git push ${PUSH_ARGS} origin "${DOWNSTREAM_BRANCH}" || { echo -e "${RED}Push failed${RESET}"; exit 7; }
else
  echo -e "${CYAN}Already up to date with upstream.${RESET}"
fi

echo -e "${YELLOW}Cleaning up...${RESET}"
cd ..
rm -rf work
echo -e "${GREEN}Sync complete.${RESET}"
