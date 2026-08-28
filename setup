#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — one-command setup for a fresh machine.
#
# Clones the (private) custom-shell-config repo and runs ./install.sh. Meant to
# be hosted publicly (yogeshraja.github.io or a gist) and run as:
#
#   bash <(curl -fsSL https://yogeshraja.github.io/bootstrap.sh)
#
# Use the process-substitution form, NOT `curl … | bash`: piping feeds the
# script to stdin, which breaks the interactive git auth prompt. `<(…)` keeps
# your terminal on stdin so the prompt works.
#
# This script is PUBLIC — it holds no secrets. Access to the private repo comes
# from git's own HTTPS prompt (username + a Personal Access Token), never from
# anything baked in here.
#
# Overridable via env: REPO_OWNER, REPO_NAME, DEST.
# =============================================================================
set -euo pipefail

REPO_OWNER="${REPO_OWNER:-yogeshraja}"
REPO_NAME="${REPO_NAME:-.custom_shell_config}"
DEST="${DEST:-$HOME/.custom_shell_config}"
HTTPS_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"

say()  { printf '\033[1;34m▶ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# Ensure git is available (install it where we safely can).
need_git() {
  command -v git >/dev/null 2>&1 && return 0
  say "git not found — attempting to install it…"
  case "$OSTYPE" in
    darwin*)
      xcode-select --install 2>/dev/null || true
      die "Accept the Xcode Command Line Tools install (a dialog may have opened), then re-run." ;;
    linux*)
      if   command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y git
      elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y git
      elif command -v yum     >/dev/null 2>&1; then sudo yum install -y git
      elif command -v pacman  >/dev/null 2>&1; then sudo pacman -Sy --noconfirm git
      else die "Could not auto-install git. Install it, then re-run."; fi ;;
    *) die "Unsupported OS ($OSTYPE); install git manually, then re-run." ;;
  esac
}

# Clone over HTTPS — git prompts for your username + a Personal Access Token.
clone_with_https() {
  say "Cloning over HTTPS — git will prompt for your username and a Personal Access Token…"
  git clone --recursive "$HTTPS_URL" "$DEST"
}

main() {
  need_git

  if [ -d "$DEST/.git" ]; then
    say "Repo already present at ${DEST} — updating…"
    git -C "$DEST" pull --recurse-submodules --ff-only || warn "Pull failed; using the existing checkout."
  else
    mkdir -p "$(dirname "$DEST")"
    clone_with_https || die "Clone failed."
  fi

  [ -f "$DEST/install.sh" ] || die "install.sh not found in ${DEST}."
  say "Running install…"
  ( cd "$DEST" && ./install.sh )

  say "Done. Open a new terminal (or 'exec zsh') to load your shell."
  say "Tip: switch to the fast SSH remote once your keys are restored —"
  printf '     git -C %q remote set-url origin git@%s:%s/%s.git\n' \
    "$DEST" "$REPO_OWNER" "$REPO_OWNER" "$REPO_NAME"
}

main "$@"
