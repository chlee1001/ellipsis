#!/usr/bin/env bash
# Run the VM tests: build, clone the golden VM, install the app, the
# fixtures and the probe in the guest, run Tests/EllipsisVMTests against it,
# fetch the screenshots, delete the VM. See docs/plan.md, Phase 7.
# Usage: scripts/vm-test.sh [swift test args...]
#   ELLIPSIS_VM       the clone's name (default ellipsis-test)
#   ELLIPSIS_VM_KEEP  set to keep the VM running after the run, for a look
#                     over VNC (tart run ELLIPSIS_VM --vnc after tart stop)
#   ELLIPSIS_VM_REUSE set to run against an ELLIPSIS_VM that is already up,
#                     with the bundles copied again; implies KEEP
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
export ELLIPSIS_VM="${ELLIPSIS_VM:-ellipsis-test}"
vm="$root/scripts/vm.sh"

app="$("$root/scripts/bundle.sh" debug)"
fixtures=()
for n in A B C; do
  fixtures+=("$("$root/scripts/bundle-fixture.sh" "$n")")
done
swift build --package-path "$root" --product Probe >&2
probe="$(swift build --package-path "$root" --product Probe --show-bin-path)/Probe"

if [[ -z "${ELLIPSIS_VM_REUSE:-}" ]]; then
  "$vm" clone >&2
fi

"$vm" ssh 'pkill -x EllipsisDev; pkill -x FixtureA; pkill -x FixtureB; pkill -x FixtureC; rm -rf screenshots; true'
"$vm" scp "$app" "${fixtures[@]}" /Applications/
"$vm" scp "$probe" /Users/admin/probe

status=0
swift test --package-path "$root" --filter EllipsisVMTests "$@" || status=$?

mkdir -p "$root/build/vm-screenshots"
"$vm" scp-from screenshots "$root/build/vm-screenshots/" 2>/dev/null || true

if [[ -n "${ELLIPSIS_VM_KEEP:-}${ELLIPSIS_VM_REUSE:-}" ]]; then
  echo "$ELLIPSIS_VM is still running: scripts/vm.sh ssh, or scripts/vm.sh delete" >&2
else
  "$vm" delete
fi
exit "$status"
