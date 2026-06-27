# ai-notify

<p align="center"><img src="ai-notify.jpeg" alt="ai-notify" width="320"></p>

Play a sound when an AI coding agent finishes or needs your attention, but only when its
terminal window is **not** focused.  
No noise while you are watching it work, a bell when you have switched away.

<h3>Platforms: <img src="assets/linux.png" height="18" align="top"> Linux (Ubuntu), <img src="assets/apple.svg" height="18" align="top"> macOS, and <img src="assets/windows.svg" height="18" align="top"> Windows</h3>
<h3>Agents: <img src="assets/claude.svg" height="18" align="top"> <a href="#claude-code">Claude Code</a>, <img src="assets/codex.svg" height="18" align="top"> <a href="#codex">Codex</a>, and <img src="assets/opencode.svg" height="18" align="top"> <a href="#opencode">opencode</a></h3>

## Usage

Install in one command:

```sh
# Linux or Mac
git clone https://github.com/Helias/ai-notify.git && cd ai-notify && ./install.sh

# Windows
git clone https://github.com/Helias/ai-notify.git; cd ai-notify; powershell -ExecutionPolicy Bypass -File .\install.ps1
```

...or you can ask your agent to install it for you 😉

## How it works

On Linux and macOS, [`notify-if-unfocused.sh`](notify-if-unfocused.sh) detects the OS and the
currently focused window, walks up its own process tree, and plays a sound only when none of
its ancestor processes own the focused window. On Windows,
[`notify-if-unfocused.ps1`](notify-if-unfocused.ps1) does the same with the Win32 API.

- <img src="assets/linux.png" height="16" align="top"> **Linux**: focused window via `xdotool`; sound via the first available player, trying
  `paplay`, `pw-play`, `ffplay`, then `aplay`.
- <img src="assets/apple.svg" height="16" align="top"> **macOS**: frontmost app via `osascript`, sound via `afplay`.
- <img src="assets/windows.svg" height="16" align="top"> **Windows**: foreground window via `GetForegroundWindow`/`GetWindowThreadProcessId`
  (PowerShell + Win32); sound via a built-in notification `.wav` (`System.Media.SoundPlayer`),
  falling back to a system sound. `conhost.exe`/`OpenConsole.exe` windows are resolved to their
  owning shell so classic consoles and Windows Terminal both work.

### Requirements

`install.sh` checks for these and offers to install any that are missing using your package
manager. You can also install them yourself:

- **Linux**: `xdotool` (`sudo apt install xdotool`). Works on X11; Wayland support depends on
  `xdotool` compatibility. For sound you almost certainly already have a player (`paplay` or
  `pw-play` ship with the PulseAudio/PipeWire desktop stack); only if you have none of `paplay`,
  `pw-play`, `ffplay`, or `aplay` do you need to install one, e.g. `sudo apt install ffmpeg`.
- **macOS**: no extra tooling, `osascript` and `afplay` ship with the system.
- **Windows**: no extra tooling. `notify-if-unfocused.ps1` and `install.ps1` use only built-in
  PowerShell (5.1+, ships with Windows) and the Win32 API — no `jq`, `xdotool`, or sound player
  to install. If your environment restricts scripts, the installer/hook commands already pass
  `-ExecutionPolicy Bypass`.
- `jq` is required by `install.sh` (Linux/macOS only). Install it with `sudo apt install jq` or
  `brew install jq`. The Windows installer (`install.ps1`) does its JSON merging natively and
  needs no `jq`.

## Configurations

<a id="claude-code"></a>

<details>
<summary><img src="assets/claude.svg" height="18" align="top">&nbsp;<b>Claude Code</b></summary>

Merge the `hooks` (and `preferredNotifChannel`) from [`templates/claude/settings.json`](templates/claude/settings.json)
into your `~/.claude/settings.json`. It fires the script on `Stop` and on permission/idle
notifications.

```json
{
  "preferredNotifChannel": "notifications_disabled",
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash [COMMAND_PATH]/notify-if-unfocused.sh"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt|idle_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "bash [COMMAND_PATH]/notify-if-unfocused.sh"
          }
        ]
      }
    ]
  }
}
```

On <img src="assets/windows.svg" height="14" align="top"> **Windows**, use [`templates/claude/settings.windows.json`](templates/claude/settings.windows.json)
instead (same structure, with the command set to
`powershell -NoProfile -ExecutionPolicy Bypass -File "[COMMAND_PATH]/notify-if-unfocused.ps1"`).
`.\install.ps1 claude` does this merge for you.

</details>

<a id="codex"></a>

<details>
<summary><img src="assets/codex.svg" height="18" align="top">&nbsp;<b>Codex</b></summary>

Copy [`templates/codex/hooks.json`](templates/codex/hooks.json) to `~/.codex/hooks.json` (or merge
its `hooks` into your existing one). It fires the script on `Stop`.

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "[COMMAND_PATH]/notify-if-unfocused.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

On <img src="assets/windows.svg" height="14" align="top"> **Windows**, use [`templates/codex/hooks.windows.json`](templates/codex/hooks.windows.json)
instead (command set to `powershell -NoProfile -ExecutionPolicy Bypass -File "[COMMAND_PATH]/notify-if-unfocused.ps1"`).
`.\install.ps1 codex` does this for you.

</details>

<a id="opencode"></a>

<details>
<summary><img src="assets/opencode.svg" height="18" align="top">&nbsp;<b>opencode</b></summary>

Two files under `~/.config/opencode/`:

1. [`templates/opencode/opencode.jsonc`](templates/opencode/opencode.jsonc) enables the built-in
   attention notification:

   ```jsonc
   {
     "$schema": "https://opencode.ai/config.json",
     "tui": {
       "attention": {
         "notify": true,
         "sound": true,
       },
     },
   }
   ```

2. [`templates/opencode/plugin/notify.js`](templates/opencode/plugin/notify.js) runs the script on
   `session.idle`. Remember to replace `[COMMAND_PATH]` inside it.

   On <img src="assets/windows.svg" height="14" align="top"> **Windows**, use
   [`templates/opencode/plugin/notify.windows.js`](templates/opencode/plugin/notify.windows.js)
   instead — it invokes `notify-if-unfocused.ps1` via `powershell`. `.\install.ps1 opencode`
   installs it for you. (`opencode.jsonc` is identical on every platform.)

</details>
