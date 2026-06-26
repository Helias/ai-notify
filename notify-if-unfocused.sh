#!/usr/bin/env bash

# Play through the first available player. paplay/pw-play ship with the PulseAudio/PipeWire
# stack already present on desktops, so most users need no extra install; ffplay (ffmpeg) and
# aplay are fallbacks. aplay handles WAV only, so it gets a WAV sound.
play_sound() {
  local oga=/usr/share/sounds/freedesktop/stereo/bell.oga
  local wav=/usr/share/sounds/alsa/Front_Center.wav

  if command -v paplay >/dev/null 2>&1; then
    paplay "$oga" >/dev/null 2>&1 && return
  fi
  if command -v pw-play >/dev/null 2>&1; then
    pw-play "$oga" >/dev/null 2>&1 && return
  fi
  if command -v ffplay >/dev/null 2>&1; then
    timeout 3s ffplay -nodisp -autoexit -loglevel quiet "$oga" >/dev/null 2>&1 && return
  fi
  if command -v aplay >/dev/null 2>&1; then
    aplay "$wav" >/dev/null 2>&1 && return
  fi
}

notify_linux() {
  local a p f
  a=$(xdotool getactivewindow getwindowpid 2>/dev/null || :)
  p=$$
  f=0
  while [ "$p" -gt 1 ]; do
    [ "$p" = "$a" ] && { f=1; break; }
    p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
    [ -z "$p" ] && break
  done

  [ "$f" -eq 0 ] && play_sound
}

notify_macos() {
  local sound=/System/Library/Sounds/Blow.aiff

  local fp p
  fp=$(lsappinfo info -only pid "$(lsappinfo front)" 2>/dev/null | sed 's/[^0-9]//g')
  p=$$
  while [ -n "$p" ] && [ "$p" -gt 1 ]; do
    [ "$p" = "$fp" ] && return 0
    p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
  done

  afplay "$sound" >/dev/null 2>&1 || :
}

case "$(uname -s)" in
  Darwin) notify_macos ;;
  *)      notify_linux ;;
esac

# Codex's Stop hook rejects empty/plain-text stdout as invalid; emit a minimal valid JSON object.
# Harmless to Claude Code (no-op decision) and ignored by the opencode plugin.
printf '{}\n'
exit 0
