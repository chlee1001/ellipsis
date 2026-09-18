#!/usr/bin/env bash
# Tart guest for the VM tests. See docs/plan.md, Phase 7.
# Usage: scripts/vm.sh prepare          clone the base image as the golden VM and put the ssh key in it
#        scripts/vm.sh clone            clone the golden VM as $ELLIPSIS_VM and boot it headless
#        scripts/vm.sh ip               print the guest IP, waiting for it
#        scripts/vm.sh ssh [CMD...]     run a command in the guest, or open a shell
#        scripts/vm.sh scp SRC... DST   copy into the guest; DST is a guest path
#        scripts/vm.sh stop | delete    stop, or stop and delete, $ELLIPSIS_VM
set -euo pipefail

base="ghcr.io/cirruslabs/macos-golden-gate-base:latest"
golden="${ELLIPSIS_VM_GOLDEN:-ellipsis-golden}"
vm="${ELLIPSIS_VM:-ellipsis-test}"
user="admin"
key="$HOME/.tart/ellipsis_ed25519"
ssh_opts=(-i "$key" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)

ip() { tart ip "$1" --wait 120; }

case "${1:-}" in
  prepare)
    # The image grants Accessibility, Full Disk Access and Apple Events to
    # sshd, so the guest needs nothing but our key. See docs/phase7.md.
    if [[ ! -f "$key" ]]; then
      ssh-keygen -t ed25519 -N "" -C ellipsis-vm -f "$key" -q
    fi
    tart delete "$golden" 2>/dev/null || true
    tart clone "$base" "$golden"
    tart set "$golden" --cpu 4 --memory 8192
    nohup tart run "$golden" --no-graphics > /dev/null 2>&1 &
    addr="$(ip "$golden")"
    expect -c "
      set timeout 120
      spawn ssh-copy-id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $key.pub $user@$addr
      expect assword: { send $user\\r }
      expect eof
    " > /dev/null
    ssh "${ssh_opts[@]}" "$user@$addr" 'sudo shutdown -h now' >/dev/null 2>&1 || true
    while [[ "$(tart get "$golden" --format json | plutil -extract Running raw -)" == true ]]; do sleep 1; done
    echo "$golden is ready"
    ;;
  clone)
    tart delete "$vm" 2>/dev/null || true
    tart clone "$golden" "$vm"
    nohup tart run "$vm" --no-graphics > /dev/null 2>&1 &
    addr="$(ip "$vm")"
    until ssh "${ssh_opts[@]}" -o ConnectTimeout=2 "$user@$addr" true 2>/dev/null; do sleep 1; done
    echo "$addr"
    ;;
  ip)
    ip "$vm"
    ;;
  ssh)
    shift
    exec ssh "${ssh_opts[@]}" "$user@$(ip "$vm")" "$@"
    ;;
  scp)
    shift
    dst="${*: -1}"
    exec scp "${ssh_opts[@]}" -r "${@:1:$#-1}" "$user@$(ip "$vm"):$dst"
    ;;
  stop)
    tart stop "$vm"
    ;;
  delete)
    tart stop "$vm" 2>/dev/null || true
    tart delete "$vm"
    ;;
  *)
    sed -n '2,8p' "$0" >&2
    exit 1
    ;;
esac
