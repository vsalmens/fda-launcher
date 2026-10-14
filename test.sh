#!/bin/bash
# Self-test: builds launchers for a dummy command and checks quoting, argument
# isolation, exit codes and the rebuild stamp. Runs on macOS and Linux.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/dir with space"
cat > "$TMP/dir with space/job" <<'EOF'
#!/bin/sh
for a in "$@"; do printf '[%s]' "$a"; done; echo
exit 7
EOF
chmod +x "$TMP/dir with space/job"

fail() { echo "FAIL: $1"; exit 1; }

out="$("$HERE/build-launcher.sh" --name demo --out "$TMP/bin/demo" -- "$TMP/dir with space/job" 'a "quoted" arg' 'back\slash' 2>/dev/null | tail -1)"
[ "$out" = "$TMP/bin/demo" ] || fail "path not printed"

set +e
got="$("$out" --ignored extra args)"
code=$?
set -e
[ "$got" = '[a "quoted" arg][back\slash]' ] || fail "arguments: $got"
[ "$code" = 7 ] || fail "exit code $code"

before="$(shasum -a 256 "$out" | cut -d' ' -f1)"
msg="$("$HERE/build-launcher.sh" --name demo --out "$TMP/bin/demo" -- "$TMP/dir with space/job" 'a "quoted" arg' 'back\slash' 2>&1 >/dev/null)"
[[ "$msg" == *unchanged* ]] || fail "rebuilt without changes"
[ "$before" = "$(shasum -a 256 "$out" | cut -d' ' -f1)" ] || fail "binary changed"

msg="$("$HERE/build-launcher.sh" --name demo --out "$TMP/bin/demo" -- "$TMP/dir with space/job" other 2>&1 >/dev/null)"
[[ "$msg" == *built* ]] || fail "command change did not rebuild"

"$HERE/build-launcher.sh" --name Bad -- /bin/true 2>/dev/null && fail "accepted bad name"
"$HERE/build-launcher.sh" --name demo -- relative/path 2>/dev/null && fail "accepted relative command"

if command -v python3 >/dev/null; then
  FDA_LAUNCHER_NO_LOAD=1 HOME="$TMP/home" "$HERE/build-launcher.sh" --name demo --launchd local.demo.sync --watch "$TMP/a <b> & c" \
    --interval 60 -- "$TMP/dir with space/job" >/dev/null 2>&1 || true
  python3 - "$TMP/home/Library/LaunchAgents/local.demo.sync.plist" "$TMP/a <b> & c" <<'PY' || fail "plist"
import plistlib, sys
d = plistlib.load(open(sys.argv[1], "rb"))
assert d["WatchPaths"] == [sys.argv[2]] and d["StartInterval"] == 60
assert d["ProgramArguments"][0].endswith("/demo/bin/demo-launcher")
PY
fi

echo "ok"
