#!/usr/bin/env bash
set -euo pipefail
[[ $(omarchy-shell lock isLocked) == false ]] || { echo 'Restore from an unlocked desktop session.' >&2; exit 1; }
config_path="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"
backup=$(mktemp "${config_path}.before-lockscreen-restore.XXXXXXXX")
cp -p "$config_path" "$backup"
omarchy plugin disable velunori.lockscreen || echo 'Disable IPC interrupted; restarting to apply the saved configuration.' >&2
omarchy restart shell
echo "Built-in Omarchy lock screen restored. Configuration backup: $backup"
