# Development install

```sh
ln -s ~/Work/omarchy-kbullet ~/.config/omarchy/plugins/brightwalker25.kbullet
omarchy-shell shell rescanPlugins
omarchy plugin enable brightwalker25.kbullet --section right --before omarchy.network
```

The symlink is what makes your edits live. The plugin id is taken from the link
name, so it has to be exactly `brightwalker25.kbullet` whatever the checkout is
called.

Saving any file under `~/.config/omarchy/plugins/` reloads the plugin code
automatically. If a change does not take effect, fall back to:

```sh
omarchy-restart-shell
```

## Checking it

```sh
omarchy plugin validate ~/Work/omarchy-kbullet
omarchy-shell shell listPlugins | grep kbullet
bin/kbullet-today --text
omarchy-shell brightwalker25.kbullet toggle
```

QML errors surface in the shell's log:

```sh
journalctl --user -f | grep -i kbullet
```

## Moving it in the bar

```sh
omarchy plugin enable brightwalker25.kbullet --section right --after omarchy.tray
omarchy plugin disable brightwalker25.kbullet
```

Or edit `bar.layout` in `~/.config/omarchy/shell.json` directly.
