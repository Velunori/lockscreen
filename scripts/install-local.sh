#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd "$(dirname "$0")/.." && pwd -P)
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
plugin_dir="$config_dir/plugins/velunori.lockscreen"
lib_dir="$config_dir/plugins/lib"
omarchy_dir="${OMARCHY_PATH:-/usr/share/omarchy}"
for executable in omarchy omarchy-shell python3; do
  command -v "$executable" >/dev/null || { echo "Missing: $executable" >&2; exit 1; }
done
cmp "$repo_dir/Service.qml" "$omarchy_dir/shell/plugins/lock/Service.qml" || { echo 'Merge the current Omarchy lock service before installing.' >&2; exit 1; }
[[ -r /etc/pam.d/omarchy-lock-password ]] || { echo 'Omarchy lock PAM configuration is missing.' >&2; exit 1; }
[[ $(omarchy-shell shell ping) == ok ]] || { echo 'Omarchy shell is not running.' >&2; exit 1; }
[[ $(omarchy-shell lock isLocked) == false ]] || { echo 'Install from an unlocked desktop session.' >&2; exit 1; }
bash "$lib_dir/scripts/check-install.sh"
bash "$lib_dir/scripts/check-consumer.sh" "$repo_dir"
if [[ -e "$plugin_dir" || -L "$plugin_dir" ]]; then
  [[ -L "$plugin_dir" && $(readlink -f "$plugin_dir") == "$repo_dir" ]] || { echo "Refusing to replace $plugin_dir" >&2; exit 1; }
fi
omarchy-shell shell listPlugins | python3 -c '
import json,sys
others=[p["id"] for p in json.load(sys.stdin) if p.get("enabled") and p.get("clonedFrom")=="omarchy.lock" and p["id"]!="velunori.lockscreen"]
if others: sys.exit("Another lock replacement is active: " + ", ".join(others))
'
backup=$(mktemp "$config_dir/shell.json.before-velunori-lockscreen.XXXXXXXX")
cp -p "$config_dir/shell.json" "$backup"
echo "Configuration backup: $backup"
[[ -L "$plugin_dir" ]] || ln -s "$repo_dir" "$plugin_dir"
omarchy-shell shell rescanPlugins
ready=false
for attempt in {1..30}; do
  if omarchy-shell shell listPlugins | python3 -c 'import json,sys; sys.exit(0 if any(p.get("id")=="velunori.lockscreen" for p in json.load(sys.stdin)) else 1)'; then ready=true; break; fi
  sleep 0.2
done
[[ $ready == true ]] || { echo 'Lockscreen discovery failed; configuration was not changed.' >&2; exit 1; }
if ! omarchy plugin enable velunori.lockscreen; then echo 'Enable IPC interrupted; restarting to verify the saved configuration.' >&2; fi
omarchy restart shell
ready=false
for attempt in {1..60}; do
  if omarchy-shell lock status 2>/dev/null | python3 -c 'import json,sys; state=json.load(sys.stdin); sys.exit(0 if state.get("passwordPam") and not state.get("locked") else 1)' && python3 - "$config_dir/shell.json" <<'PY'
import json,sys
config=json.load(open(sys.argv[1]))
plugins=[p.get('id') if isinstance(p,dict) else p for p in config.get('plugins',[])]
sys.exit(0 if 'velunori.lockscreen' in plugins and 'omarchy.lock' in config.get('disabledPlugins',[]) else 1)
PY
  then ready=true; break; fi
  sleep 0.25
done
if [[ $ready != true ]]; then
  cp -p "$backup" "$config_dir/shell.json"
  omarchy restart shell || true
  echo "Lock service verification failed; restored $backup" >&2
  exit 1
fi
echo 'Serene installed. Preview without locking: omarchy-shell lock preview'
echo "Restore: bash $repo_dir/scripts/restore-local.sh"
