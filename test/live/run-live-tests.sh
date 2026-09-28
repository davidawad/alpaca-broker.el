#!/usr/bin/env bash
# Runs the live ERT suite (test/live/alpaca-broker-live-test.el) against
# Alpaca's PAPER trading environment.
#
# Resolves ALPACA_API_PAPER_KEY / ALPACA_API_PAPER_SECRET via David's
# credentials resolver (infrastructure/trading/credentials.py in
# ~/.dotfiles, override the repo with $ALPACA_BROKER_DOTFILES) and
# exports them only into this script's own Emacs subprocess -- never
# printed, logged, or written to a file. If the resolver can't find the
# dotfiles repo or the credentials don't resolve, the env vars are left
# unset and the live ERT suite skips every test itself (see
# `alpaca-broker-live-test--skip-unless-credentialed' in
# alpaca-broker-live-test.el) rather than failing.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dotfiles_root="${ALPACA_BROKER_DOTFILES:-$HOME/.dotfiles}"

if [ -d "$dotfiles_root/infrastructure/trading" ]; then
  resolved="$(cd "$dotfiles_root" && python3 -c '
import sys
sys.path.insert(0, ".")
from infrastructure.trading import credentials
print(credentials.resolve("ALPACA_API_PAPER_KEY") or "")
print(credentials.resolve("ALPACA_API_PAPER_SECRET") or "")
' 2> /dev/null || true)"
  resolved_key="$(printf '%s\n' "$resolved" | sed -n 1p)"
  resolved_secret="$(printf '%s\n' "$resolved" | sed -n 2p)"
  if [ -n "$resolved_key" ] && [ -n "$resolved_secret" ]; then
    export ALPACA_API_PAPER_KEY="$resolved_key"
    export ALPACA_API_PAPER_SECRET="$resolved_secret"
  fi
  unset resolved resolved_key resolved_secret
fi

exec emacs -Q --batch -L "$repo_root" -L "$repo_root/test" \
  -l "$repo_root/test/live/alpaca-broker-live-test.el" \
  -f ert-run-tests-batch-and-exit
