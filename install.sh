#!/usr/bin/env bash
set -euo pipefail

# Absolute path to this repo, used as [COMMAND_PATH] in the installed configs.
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLAUDE_DST="$HOME/.claude/settings.json"
CODEX_DST="$HOME/.codex/hooks.json"
OPENCODE_CONFIG_DST="$HOME/.config/opencode/opencode.jsonc"
OPENCODE_PLUGIN_DST="$HOME/.config/opencode/plugin/notify.js"

has_jq() { command -v jq >/dev/null 2>&1; }

# Package name for a command (matches the command except where they differ).
pkg_for() {
  case "$1" in
    ffplay) echo ffmpeg ;;
    *)      echo "$1" ;;
  esac
}

# Install-command prefix for the first package manager found, or empty.
pkg_install_cmd() {
  if command -v brew    >/dev/null 2>&1; then echo "brew install";              return; fi
  if command -v apt-get >/dev/null 2>&1; then echo "sudo apt install -y";       return; fi
  if command -v dnf     >/dev/null 2>&1; then echo "sudo dnf install -y";       return; fi
  if command -v pacman  >/dev/null 2>&1; then echo "sudo pacman -S --noconfirm"; return; fi
  if command -v zypper  >/dev/null 2>&1; then echo "sudo zypper install -y";    return; fi
  echo ""
}

# Check that each given command exists; offer to install any that are missing.
# Returns nonzero if any are still missing afterwards.
ensure_deps() {
  local cmd missing=()
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  [ ${#missing[@]} -eq 0 ] && return 0

  local pkgs=()
  for cmd in "${missing[@]}"; do
    pkgs+=("$(pkg_for "$cmd")")
  done

  echo "Missing tools: ${missing[*]}"
  local prefix; prefix="$(pkg_install_cmd)"
  if [ -z "$prefix" ]; then
    echo "  No known package manager found. Install manually: ${pkgs[*]}" >&2
    return 1
  fi

  local cmdline="$prefix ${pkgs[*]}"
  printf '  Install now with "%s"? [y/N] ' "$cmdline"
  local reply=""
  read -r reply </dev/tty 2>/dev/null || read -r reply 2>/dev/null || reply=""
  case "$reply" in
    y|Y|yes|Yes) eval "$cmdline" || true ;;
    *) echo "  Skipped. Install manually: $cmdline" >&2; return 1 ;;
  esac

  missing=()
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  [ ${#missing[@]} -eq 0 ]
}

backup() {
  local f="$1"
  [ -e "$f" ] || return 0
  local b="$f.bak.$(date +%Y%m%d%H%M%S)"
  cp "$f" "$b"
  echo "  backed up existing $f -> $b"
}

# Render a source file with [COMMAND_PATH] replaced, to stdout.
render() {
  sed "s#\[COMMAND_PATH\]#$SRC#g" "$1"
}

# Install a JSON config: deep-merge into an existing target with jq (new keys win).
# Never overwrites: if the target cannot be parsed as JSON, it is left untouched.
install_json() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  local rendered; rendered="$(render "$src")"

  if [ -e "$dst" ]; then
    local merged
    if ! merged="$(printf '%s' "$rendered" | jq -s '.[0] * .[1]' "$dst" - 2>/dev/null)"; then
      echo "  ERROR: $dst is not valid JSON; leaving it untouched. Merge from $src manually." >&2
      return 0
    fi
    backup "$dst"
    printf '%s\n' "$merged" > "$dst"
    echo "  merged into $dst"
  else
    printf '%s\n' "$rendered" > "$dst"
    echo "  wrote $dst"
  fi
}

# Install a plain file (no JSON merge): back up then overwrite.
install_file() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  backup "$dst"
  render "$src" > "$dst"
  echo "  wrote $dst"
}

# Decide which agent configs to install. Honors CLI args (e.g. `./install.sh claude opencode`
# or `all`); otherwise prompts. Sets DO_CLAUDE / DO_CODEX / DO_OPENCODE.
DO_CLAUDE=0 DO_CODEX=0 DO_OPENCODE=0
select_targets() {
  local choice=""
  if [ "$#" -gt 0 ]; then
    choice="$*"
  else
    echo "Which agent configs do you want to install?"
    echo "  1) Claude Code"
    echo "  2) Codex"
    echo "  3) opencode"
    echo "  4) All"
    printf 'Choose (e.g. 1 3, or 4 for all) [4]: '
    read -r choice </dev/tty 2>/dev/null || read -r choice 2>/dev/null || choice=""
    [ -z "$choice" ] && choice="4"
  fi

  local c
  for c in $(printf '%s' "$choice" | tr ',' ' '); do
    case "$c" in
      1|claude|claude-code|claudecode) DO_CLAUDE=1 ;;
      2|codex)                         DO_CODEX=1 ;;
      3|opencode)                      DO_OPENCODE=1 ;;
      4|all|a)                         DO_CLAUDE=1; DO_CODEX=1; DO_OPENCODE=1 ;;
      *) echo "  Ignoring unknown choice: $c" >&2 ;;
    esac
  done

  if [ "$DO_CLAUDE$DO_CODEX$DO_OPENCODE" = "000" ]; then
    echo "Nothing selected; defaulting to All."
    DO_CLAUDE=1; DO_CODEX=1; DO_OPENCODE=1
  fi
}

echo "Installing ai-notify from: $SRC"

select_targets "$@"

# jq is needed only to merge the JSON configs (Claude/Codex); xdotool is a Linux runtime dep of
# notify-if-unfocused.sh. A sound player is also needed on Linux, but desktops almost always
# already have one (paplay/pw-play), so only offer to install ffmpeg if none is present.
reqs=()
{ [ "$DO_CLAUDE" = 1 ] || [ "$DO_CODEX" = 1 ]; } && reqs+=(jq)
[ "$(uname -s)" = "Darwin" ] || reqs+=(xdotool)
[ ${#reqs[@]} -gt 0 ] && { ensure_deps "${reqs[@]}" || true; }

if [ "$(uname -s)" != "Darwin" ] \
   && ! command -v paplay >/dev/null 2>&1 && ! command -v pw-play >/dev/null 2>&1 \
   && ! command -v ffplay >/dev/null 2>&1 && ! command -v aplay  >/dev/null 2>&1; then
  echo "No sound player found (paplay, pw-play, ffplay, or aplay)."
  ensure_deps ffplay || true
fi

if { [ "$DO_CLAUDE" = 1 ] || [ "$DO_CODEX" = 1 ]; } && ! has_jq; then
  echo "ERROR: jq is required so existing JSON configs are merged, never overwritten." >&2
  exit 1
fi

chmod +x "$SRC/notify-if-unfocused.sh"

if [ "$DO_CLAUDE" = 1 ]; then
  echo "Claude Code:"
  install_json "$SRC/templates/claude/settings.json" "$CLAUDE_DST"
fi

if [ "$DO_CODEX" = 1 ]; then
  echo "Codex:"
  install_json "$SRC/templates/codex/hooks.json" "$CODEX_DST"
fi

if [ "$DO_OPENCODE" = 1 ]; then
  echo "opencode:"
  # opencode.jsonc may contain comments, which jq cannot merge, so never touch an existing one.
  if [ -e "$OPENCODE_CONFIG_DST" ]; then
    echo "  $OPENCODE_CONFIG_DST exists; leaving it untouched. Merge the 'tui.attention' block from $SRC/templates/opencode/opencode.jsonc manually."
  else
    install_file "$SRC/templates/opencode/opencode.jsonc" "$OPENCODE_CONFIG_DST"
  fi
  install_file "$SRC/templates/opencode/plugin/notify.js" "$OPENCODE_PLUGIN_DST"
fi

echo "Done."
