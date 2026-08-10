#!/usr/bin/env bash
# Stage, commit, and push everything on your CURRENT branch.
# You run this yourself whenever you want to upload your progress -
# nothing in this repo calls it automatically, so you always control
# what gets committed and when.
#
# Usage: ./scripts/push_my_work.sh "commit message describing what you did"

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

MSG="${1:-}"
[[ -n "$MSG" ]] || { echo "Usage: ./scripts/push_my_work.sh \"commit message\"" >&2; exit 1; }

BRANCH="$(git branch --show-current)"
[[ "$BRANCH" != "main" ]] || { echo "Refusing to push directly to main - switch to your feature branch first." >&2; exit 1; }

echo "==> Branch: $BRANCH"
git status --short

git add -A -- . ':!.env' ':!Dataset/*.csv' ':!Python/Logs/*.log' ':!.venv'
if git diff --cached --quiet; then
  echo "==> Nothing staged (no changes, or everything is gitignored) - nothing to push."
  exit 0
fi

git commit -m "$MSG"
git push -u origin "$BRANCH"
echo "==> Pushed to origin/$BRANCH"
