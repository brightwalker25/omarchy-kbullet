# Changelog

All notable changes to this plugin are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-09-25

The first public version.

### Added
- A bar widget: a notebook glyph and the count of today's open entries.
- A panel with today's Morning, Afternoon and Evening sections, read from
  Kbullet's own markdown file for the day, with Open Kbullet and Quick capture
  buttons.
- `bin/kbullet-today`, which reads the day's journal file and prints it as JSON
  for the bar, or as plain text with `--text`.
- `bin/kbullet-focus`, which focuses the Kbullet window by its exact window
  class, or starts Kbullet if it is not running.
