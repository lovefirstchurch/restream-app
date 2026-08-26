#!/usr/bin/env bash
#
# trigger_next_run.sh
# The default GITHUB_TOKEN can't start a new workflow run (to prevent
# infinite recursion), so this uses a Personal Access Token (stored as the
# GH_PAT secret) to immediately dispatch the next run right as this one
# ends, keeping the gap between streaming sessions to a few seconds instead
# of waiting on the cron schedule.

set -euo pipefail

if [ -z "${GH_PAT:-}" ]; then
  echo "GH_PAT secret not set — relying on the cron schedule instead of instant chaining." >&2
  exit 0
fi

curl -sS -X POST \
  -H "Authorization: token ${GH_PAT}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/workflows/restream.yml/dispatches" \
  -d '{"ref":"main"}'

echo "Next run dispatched."
