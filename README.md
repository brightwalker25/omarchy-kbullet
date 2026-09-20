# Kbullet, an Omarchy bar plugin

This plugin puts today's bullet journal in the Omarchy bar: the number of things
still owed at a glance, and the day itself one click away.

It is an optional extra for people who run [Omarchy](https://omarchy.org). It
lives in its own repository because
[Kbullet](https://github.com/brightwalker25/kbullet) itself is a plain PyQt6
application that runs on any Linux desktop and has no need of it. Installing the
plugin adds nothing to Kbullet and changes nothing about it, and removing the
plugin leaves Kbullet untouched.

```
󰠮 2        ┌─────────────────────────────────┐
           │ Sunday 20 September             │
           │ 2 open                          │
           │ checked 11:50                   │
           │ ─────────────────────────────── │
           │ MORNING                         │
           │  •  10:56  draft the report     │
           │  •  11:30  chase the invoice    │
           │ ─────────────────────────────── │
           │ AFTERNOON                       │
           │  nothing yet                    │
           │ ─────────────────────────────── │
           │ EVENING                         │
           │  nothing yet                    │
           │ ─────────────────────────────── │
           │ [ Open Kbullet ][ Quick capture]│
           └─────────────────────────────────┘
```

## What it does

- **In the bar:** a notebook glyph followed by the count of open entries. The
  glyph takes the bar's urgent colour when the day holds an urgent entry.
- **In the panel:** today's Morning, Afternoon and Evening sections, using
  Kbullet's own symbol colours. Completed entries are greyed out and struck
  through.
- **Open Kbullet:** focuses the running app, or launches it if it is not
  running.
- **Quick capture:** runs the `quick-capture` command, so you can add an entry
  without opening the app. This is a separate small utility, not the same thing
  as Kbullet's own system-tray quick capture, and the button does nothing if the
  command is not installed.

Left-click toggles the panel, right-click opens Kbullet, and middle-click forces
a refresh.

## Installing

```sh
git clone https://github.com/brightwalker25/omarchy-kbullet.git ~/Work/omarchy-kbullet
ln -s ~/Work/omarchy-kbullet ~/.config/omarchy/plugins/brightwalker25.kbullet
omarchy-shell shell rescanPlugins
omarchy plugin enable brightwalker25.kbullet --section right --before omarchy.network
```

The symlink name must be exactly `brightwalker25.kbullet`, because the plugin id
is taken from the link name whatever the checkout is called.

See [INSTALL.md](INSTALL.md) for the development workflow.

## Settings

Settings are stored per widget in `~/.config/omarchy/shell.json`, and can also
be edited with `omarchy plugin configure brightwalker25.kbullet`.

| Key | Default | Meaning |
|---|---|---|
| `refreshIntervalMs` | `30000` | How often to re-read the journal while the panel is open |
| `backgroundIntervalMs` | `300000` | How often to refresh the badge while the panel is closed. This is only a backstop, since the folder is also watched |
| `showCount` | `true` | Show the open count beside the glyph |
| `hideDone` | `false` | Hide completed entries |
| `journalDir` | `""` | Override the journal folder. Leave empty to use Kbullet's own setting |

## How it reads the journal

All of the work happens in `bin/kbullet-today`, which emits JSON. It resolves
`journal_dir` from `~/.config/Kbullet/Settings.conf`, reads today's
`YYYY-MM-DD.md`, and maps Kbullet's eleven symbols onto names that the panel
can colour. Nothing about the file format lives in the QML, so a change to
Kbullet only ever touches this one script.

The script runs perfectly well on its own:

```sh
bin/kbullet-today --text        # human-readable
bin/kbullet-today --pretty      # indented JSON
bin/kbullet-today --count-only  # just the counts
bin/kbullet-today --date 2026-09-14
```

The panel refreshes on a timer while it is open, and the journal folder is
watched so that an entry added by `quick-capture`, or one arriving over
Syncthing or Synology Drive, appears without waiting. It watches the folder
rather than the file for two reasons: today's file may not exist yet, and sync
clients typically write to a temporary file and then rename it.

## Why it uses its own focuser

Omarchy ships `omarchy-launch-or-focus`, but that helper matches its pattern
against the window class or the window title, using a word-boundary regular
expression. Every browser tab showing the Kbullet repository, every editor
holding `kbullet.py`, and every terminal running the command have "kbullet"
somewhere in their titles, and the helper will happily focus one of those
instead of the app. `bin/kbullet-focus` matches the window class exactly.

This requires Kbullet 2.1.0 or newer, which sets a real Wayland `app_id`. Older
builds report their class as `python3`, so the focuser falls back to matching
their exact `Kbullet - YYYY-MM-DD` title.

## Summoning the panel from a keybinding

The panel exposes an IPC target. Add this to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + Q", "Kbullet today", "omarchy-shell brightwalker25.kbullet toggle")
```

The methods `open`, `close`, `show`, `hide`, `toggle` and `refresh` are all
available.

## Notes

- The symbol colours are Kbullet's own, and they are deliberately not themed.
  The colours carry the entry's meaning, and an entry that reads as one kind
  here and another in the app would be worse than no colour at all. Two of them,
  amber for notes and gold for priority, are a little weak against a light
  theme.
- The plugin is built against Omarchy 4's shell APIs, including `KeyboardPanel`,
  `PanelKeyCatcher` and `Style.space()`. These are internal and may change
  between releases.
- Third-party plugins are not sandboxed inside `omarchy-shell`.

## Licence

This plugin is licensed under the MIT licence. See [LICENSE](LICENSE).

The panel and bar-widget scaffolding is derived from Omarchy's own
`omarchy.weather` and `omarchy.agents` plugins, which are MIT licensed and
Copyright (c) David Heinemeier Hansson. Their notice is reproduced in
[NOTICE](NOTICE).
