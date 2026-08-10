# Stage, commit, and push everything on your CURRENT branch.
# You run this yourself whenever you want to upload your progress.
#
# Usage: .\scripts\push_my_work.ps1 "commit message describing what you did"

param([Parameter(Mandatory=$true)][string]$Message)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

$branch = git branch --show-current
if ($branch -eq "main") {
    Write-Host "Refusing to push directly to main - switch to your feature branch first." -ForegroundColor Red
    exit 1
}

Write-Host "==> Branch: $branch"
git status --short

git add -A -- . ':!.env' ':!Dataset/*.csv' ':!Python/Logs/*.log' ':!.venv'
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "==> Nothing staged (no changes, or everything is gitignored) - nothing to push."
    exit 0
}

git commit -m $Message
git push -u origin $branch
Write-Host "==> Pushed to origin/$branch"
