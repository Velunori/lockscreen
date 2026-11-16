#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd "$(dirname "$0")/.." && pwd -P)
lib_dir="${VELUNORI_LIB_PATH:-$(dirname "$repo_dir")/lib}"
omarchy_dir="${OMARCHY_PATH:-/usr/share/omarchy}"
layout="${VELUNORI_TEST_LAYOUT:-copy}"
[[ "$layout" == copy || "$layout" == symlink ]] || { echo 'Unknown test layout' >&2; exit 1; }
# An upstream auth update must be merged deliberately, never silently bypassed.
cmp "$repo_dir/Service.qml" "$omarchy_dir/shell/plugins/lock/Service.qml"
python3 - "$repo_dir/manifest.json" <<'PY'
import json,sys
manifest=json.load(open(sys.argv[1]))
assert manifest['id']=='velunori.lockscreen'
assert manifest['kinds']==['service']
assert manifest['omarchy']['clonedFrom']=='omarchy.lock'
assert manifest['entryPoints']['service']=='Service.qml'
PY
runtime_dir=$(mktemp -d)
trap 'rm -rf "$runtime_dir"' EXIT
chmod 700 "$runtime_dir"
mkdir -p "$runtime_dir/velunori.lockscreen" "$runtime_dir/lib" "$runtime_dir/imports/qs"
cp "$repo_dir/"*.js "$repo_dir/"*.qml "$repo_dir/manifest.json" "$runtime_dir/velunori.lockscreen/"
cp -r "$lib_dir/kit" "$lib_dir/design" "$lib_dir/components" "$lib_dir/assets" "$runtime_dir/lib/"
if [[ "$layout" == symlink ]]; then
  mkdir "$runtime_dir/checkouts"
  mv "$runtime_dir/velunori.lockscreen" "$runtime_dir/checkouts/lockscreen"
  mv "$runtime_dir/lib" "$runtime_dir/checkouts/lib"
  ln -s "$runtime_dir/checkouts/lockscreen" "$runtime_dir/velunori.lockscreen"
  ln -s "$runtime_dir/checkouts/lib" "$runtime_dir/lib"
fi
for module in Commons Ui; do
  ln -s "$omarchy_dir/shell/$module" "$runtime_dir/imports/qs/$module"
  ln -s "$omarchy_dir/shell/$module" "$runtime_dir/$module"
done
/usr/lib/qt6/bin/qmllint -I "$runtime_dir/imports" --unqualified info --missing-property warning --incompatible-type info \
  "$runtime_dir/velunori.lockscreen/LockView.qml" > "$runtime_dir/lint.log" 2>&1 || { cat "$runtime_dir/lint.log"; exit 1; }
cp "$repo_dir/tests/ui.qml" "$runtime_dir/shell.qml"
# Tests instantiate ONLY LockView in a regular window. They never load the
# service, PAM or WlSessionLock, and never lock or unlock the desktop.
env -u WAYLAND_DISPLAY -u DISPLAY XDG_RUNTIME_DIR="$runtime_dir" XDG_CONFIG_HOME="$runtime_dir/config" \
  QML_IMPORT_PATH="$runtime_dir/imports" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic QT_QUICK_CONTROLS_STYLE=Basic QT_QUICK_BACKEND=software \
  timeout 15s quickshell -p "$runtime_dir/shell.qml" --no-color > "$runtime_dir/ui.log" 2>&1 || { cat "$runtime_dir/ui.log"; exit 1; }
cat "$runtime_dir/ui.log"
if rg -q 'LOCKSCREEN_TEST_FAILED|Failed to load|TypeError|ReferenceError|Binding loop|Unable to assign' "$runtime_dir/ui.log"; then exit 1; fi
if [[ -n ${VELUNORI_PREVIEW_PATH:-} ]]; then rg -q 'LOCKSCREEN_PREVIEW_SAVED' "$runtime_dir/ui.log"; else rg -q 'LOCKSCREEN_TEST_PASSED' "$runtime_dir/ui.log"; fi
