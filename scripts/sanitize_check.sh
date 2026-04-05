#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v rg >/dev/null 2>&1; then
	echo "rg is required" >&2
	exit 1
fi

failures=0

check_absent() {
	local description pattern matches
	description="$1"
	pattern="$2"
	matches="$(rg -n --glob '!LICENSE' --glob '!scripts/sanitize_check.sh' "$pattern" . || true)"
	if [[ -n "$matches" ]]; then
		echo "FAIL: $description" >&2
		printf '%s\n' "$matches" >&2
		failures=$((failures + 1))
	else
		echo "PASS: $description"
	fi
}

check_not_tracked() {
	local path description
	path="$1"
	description="$2"
	if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
		echo "FAIL: $description ($path is tracked)" >&2
		failures=$((failures + 1))
	else
		echo "PASS: $description"
	fi
}

check_absent "machine-local Josh path" '/Users/josh'
check_absent "live ScreenConnect tenant URL" 'joshphillipssr\.screenconnect\.com'
check_absent "network share placeholder defaults" '\\\\SERVER\\Share|DOMAIN\\Username'
check_absent "hardcoded log share password default" 'LogSharePassword = "Password"'
check_absent "live 1Password vault reference" 'op://JoshSrAI-Agent'

check_not_tracked '.env' 'public repo does not track .env'
check_not_tracked '.secrets' 'public repo does not track .secrets'
check_not_tracked 'inventory' 'public repo does not track inventory overlays'
check_not_tracked 'overlays' 'public repo does not track private overlays'
check_not_tracked 'state' 'public repo does not track generated state'

if [[ "$failures" -ne 0 ]]; then
	echo "sanitize_check: $failures failure(s)" >&2
	exit 1
fi

echo "sanitize_check: pass"