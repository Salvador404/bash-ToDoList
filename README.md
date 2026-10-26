# Weekly To-Do Tracker

A lightweight terminal-based weekly task tracker written in Bash. Manage your weekly activities as a to-do list with target session counts, log progress, and archive past weeks into a history file.

## Features

- **Interactive menu** — view list, add tasks, log sessions, manage tasks, reset week, view history
- **Session tracking** — each task has a title and a weekly target (number of sessions)
- **Visual progress** — colored progress bars (red / yellow / green) with per-task and overall stats
- **Task management** — edit titles, change targets, or delete tasks
- **Manual weekly reset** — archives the current week to `history.log` and zeroes all counters (no date-based automation)
- **History log** — append-only `history.log` with relative week numbers, reset dates, and plain-text progress snapshots
- **No external dependencies** — pure Bash, works out of the box

## Files

- `weekly.sh` — main script
- `tasks.dat` — current week's tasks (`title|target|done`)
- `history.log` — archived weekly snapshots

## Usage

```bash
chmod +x weekly.sh
./weekly.sh
