# audio-output-guard

A tiny macOS command-line tool that keeps microphone-style Bluetooth devices from stealing your audio output.

It was originally built for a simple annoyance: when a DJI Mic Mini 2 reconnects, macOS may treat it as an output device. That can make system audio disappear into the microphone receiver instead of playing through your headphones or Mac speakers.

`audio-output-guard` watches CoreAudio device changes and nudges routing back to a sane setup:

- use the DJI microphone as the default input when it is connected;
- prefer connected headphones for output;
- fall back to built-in Mac speakers when no headphones are available;
- avoid leaving default output or system output on the DJI microphone device.

## How it works

The watcher is event-driven. It does not run a polling loop.

At login, a user LaunchAgent starts:

```text
audio-output-guard watch
```

The process registers CoreAudio listeners for audio device and default input/output changes, then sleeps until macOS sends an event.

## Requirements

- macOS 13 or newer
- Swift 5.9 or newer
- A device whose name or UID contains `DJI`, `DJI Mic`, or `DJI Mic Mini`

## Build

```bash
git clone https://github.com/InitialMoon/audio-output-guard.git
cd audio-output-guard
swift build -c release
```

The release binary will be at:

```text
.build/release/audio-output-guard
```

## Inspect devices

Before installing the watcher, check how macOS sees your audio devices:

```bash
.build/release/audio-output-guard devices
```

Useful columns:

- `IN*`: current default input
- `OUT*`: current default output
- `SYS*`: current default system output
- `IN` / `OUT`: whether the device exposes input or output channels
- `TRANSPORT`: built-in, Bluetooth, USB, HDMI, virtual, etc.

## Try a dry run

```bash
.build/release/audio-output-guard once --dry-run
```

This prints the changes it would make without changing system audio settings.

You can also test the event watcher without applying changes:

```bash
.build/release/audio-output-guard watch --dry-run
```

## Install at login

After building the release binary, install the user LaunchAgent:

```bash
.build/release/audio-output-guard install
```

This writes a LaunchAgent plist under your user `~/Library/LaunchAgents` directory and starts the watcher in the current GUI login session.

Check status:

```bash
.build/release/audio-output-guard status
```

View logs:

```bash
.build/release/audio-output-guard logs
```

Uninstall:

```bash
.build/release/audio-output-guard uninstall
```

## Put it on your PATH

Optional:

```bash
mkdir -p ~/.local/bin
ln -s "$(pwd)/.build/release/audio-output-guard" ~/.local/bin/audio-output-guard
```

Then make sure `~/.local/bin` is in your shell `PATH`.

## Privacy and safety

This tool does not record audio and does not open microphone streams. It only reads CoreAudio device metadata and changes the current user's default input/output device selection.

It does not need sudo, Accessibility permission, or microphone privacy permission.

The `devices` command prints local audio device names and UIDs, so avoid pasting that output publicly if your device names contain personal information.

## Development

Run tests:

```bash
swift test
```

Build release:

```bash
swift build -c release
```

The test suite includes a small privacy regression test to avoid accidentally committing local developer home paths into source files.

## License

MIT License. See [LICENSE](LICENSE).
