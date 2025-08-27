#!/usr/bin/env bash
# Sets up a fork-based workflow:
#   ~/Projects/<repo>/main        (tracks origin/main, syncs with upstream)
#   ~/Projects/<repo>/production  (your edits; separate worktree/branch)
#
# Requires: git, rsync (only if using --import-path)

set -euo pipefail

UPSTREAM=""
ORIGIN=""
BASE_DIR="$HOME/Projects"
REPO_NAME=""
IMPORT_PATH=""
REUSE=0     # allow reusing existing main/production dirs

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --upstream <git-url> --origin <git-url> --repo-name <name> [options]

Required:
  --upstream     Git URL of the source/course repo (e.g. git@github.com:ed-donner/llm_engineering.git)
  --origin       Git URL of YOUR fork (e.g. git@github.com:<you>/llm_engineering.git)
  --repo-name    Repository folder name under BASE_DIR (e.g. llm_engineering)

Options:
  --base-dir     Parent directory (default: ~/Projects)
  --import-path  Copy files from an existing working tree into production and commit them
  --reuse        Reuse existing ~/Projects/<repo>/main and/or production if present
  -h, --help     Show this help

Examples:
  $(basename "$0") \\
    --upstream git@github.com:ed-donner/llm_engineering.git \\
    --origin   git@github.com:<your-username>/llm_engineering.git \\
    --repo-name llm_engineering \\
    --base-dir ~/Projects \\
    --import-path ~/Projects/llm_engineering
EOF
}

# --- parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --upstream) UPSTREAM="$2"; shift 2;;
    --origin) ORIGIN="$2"; shift 2;;
    --base-dir) BASE_DIR="${2/#\~/$HOME}"; shift 2;;
    --repo-name) REPO_NAME="$2"; shift 2;;
    --import-path) IMPORT_PATH="${2/#\~/$HOME}"; shift 2;;
    --reuse) REUSE=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

[[ -z "$UPSTREAM" || -z "$ORIGIN" || -z "$REPO_NAME" ]] && { usage; exit 1; }

ROOT="$BASE_DIR/$REPO_NAME"
MAIN="$ROOT/main"
PROD="$ROOT/production"

echo "==> Setting up in: $ROOT"
mkdir -p "$ROOT"

# --- clone fork into main ---
if [[ -d "$MAIN/.git" ]]; then
  if [[ $REUSE -eq 1 ]]; then
    echo "==> Reusing existing $MAIN"
  else
    echo "ERROR: $MAIN already exists. Use --reuse or remove it."
    exit 1
  fi
else
  echo "==> Cloning your fork into $MAIN"
  git clone "$ORIGIN" "$MAIN"
fi

# --- add upstream + fetch ---
if git -C "$MAIN" remote | grep -qx upstream; then
  echo "==> 'upstream' remote already present"
else
  git -C "$MAIN" remote add upstream "$UPSTREAM"
fi
git -C "$MAIN" fetch origin --prune
git -C "$MAIN" fetch upstream --prune

# --- ensure we're on main branch ---
if ! git -C "$MAIN" rev-parse --verify main >/dev/null 2>&1; then
  DEFAULT_BRANCH=$(git -C "$MAIN" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | cut -d/ -f2 || echo "")
  if [[ -n "$DEFAULT_BRANCH" && "$DEFAULT_BRANCH" != "main" ]]; then
    echo "==> Renaming '$DEFAULT_BRANCH' -> 'main' locally"
    git -C "$MAIN" branch -m "$DEFAULT_BRANCH" main || true
  fi
fi
git -C "$MAIN" checkout -q main || git -C "$MAIN" checkout -qb main origin/main

# --- fast-forward main from upstream/main if possible ---
if git -C "$MAIN" rev-parse --verify upstream/main >/dev/null 2>&1; then
  echo "==> Fast-forwarding main from upstream/main (if possible)"
  git -C "$MAIN" merge --ff-only upstream/main || echo "   (Non-FF; leaving main as-is)"
fi
git -C "$MAIN" push -u origin main || true

# --- create production branch + push ---
if git -C "$MAIN" show-ref --verify --quiet refs/heads/production; then
  echo "==> Local 'production' branch exists"
else
  echo "==> Creating 'production' branch from main"
  git -C "$MAIN" branch production main
fi
git -C "$MAIN" push -u origin production || true

# --- create worktree for production ---
if [[ -d "$PROD/.git" || -d "$PROD" && $REUSE -eq 1 ]]; then
  echo "==> Reusing existing worktree at $PROD"
else
  if [[ -d "$PROD" ]]; then
    echo "ERROR: $PROD exists but is not a git worktree. Use --reuse or remove it."
    exit 1
  fi
  echo "==> Adding worktree at $PROD (branch: production)"
  git -C "$MAIN" worktree add "$PROD" production
fi

# --- optional import from an old working tree ---
if [[ -n "$IMPORT_PATH" ]]; then
  echo "==> Importing files from $IMPORT_PATH into production"
  command -v rsync >/dev/null 2>&1 || { echo "rsync is required for --import-path"; exit 1; }
  rsync -av --delete \
    --exclude '.git' --exclude 'main' --exclude 'production' \
    --exclude '.ipynb_checkpoints' \
    "$IMPORT_PATH"/ "$PROD"/

  pushd "$PROD" >/dev/null
  if [[ -n "$(git status --porcelain)" ]]; then
    git add -A
    git commit -m "Import prior local edits from $IMPORT_PATH"
    git push
  else
    echo "==> No changes to commit after import."
  fi
  popd >/dev/null
fi

echo
echo "✅ Done."
echo "Main directory:        $MAIN   (branch: main)"
echo "Production directory:  $PROD   (branch: production)"
echo
echo "Daily sync:"
echo "  cd \"$MAIN\" && git fetch upstream && git merge --ff-only upstream/main && git push origin main"
echo "  cd \"$PROD\" && git fetch --all && git merge main && git push"