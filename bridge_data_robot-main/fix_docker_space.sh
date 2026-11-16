#!/usr/bin/env bash
# Frees the space left behind by the failed robonet build and reconfigures Docker so
# the rebuild fits:
#   1. removes unused Docker data (stopped containers, unused images, build cache)
#   2. turns off the containerd image store, which needs ~2 copies of an image
#      while it is being built
#   3. moves Docker's storage to the data partition, if that partition is a Linux
#      filesystem and has more free space than /
#
# Usage:  sudo bash fix_docker_space.sh [-y] [TARGET_DIR]
#   -y          don't ask before deleting unused Docker data
#   TARGET_DIR  where Docker should keep its data (default: /mnt/data/docker)
#
# The only system file it edits is /etc/docker/daemon.json (a timestamped backup is
# written next to it first).

set -euo pipefail

assume_yes=false
target=/mnt/data/docker
for arg in "$@"; do
    case "$arg" in
        -y|--yes) assume_yes=true ;;
        -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
        *) target=$arg ;;
    esac
done

if [[ $EUID -ne 0 ]]; then
    echo "Run this with sudo: sudo bash $0" >&2
    exit 1
fi
for cmd in docker python3 systemctl; do
    command -v "$cmd" >/dev/null || { echo "Missing required command: $cmd" >&2; exit 1; }
done
if ! docker info >/dev/null 2>&1; then
    echo "Docker isn't running. Start it first: sudo systemctl start docker" >&2
    exit 1
fi

daemon_json=/etc/docker/daemon.json
target_parent=$(dirname "$target")

avail_bytes() { df --output=avail -B1 "$1" | tail -n 1 | tr -d ' '; }
fs_type()     { df --output=fstype "$1" | tail -n 1 | tr -d ' '; }
human()       { numfmt --to=iec "$1"; }

echo "== Disk space before =="
df -hT / "$target_parent" 2>/dev/null || df -hT /
echo
echo "== Docker usage before =="
docker system df || true
echo

# ---------------------------------------------------------------- 1. clean up
# This has to happen before the image store is switched below: anything left in the
# old store would become invisible to Docker but still take up disk space.
echo "About to delete ALL stopped containers, unused images and build cache."
echo "Running containers and volumes are kept."
if [[ -n "$(docker ps -aq)" ]]; then
    echo "Containers that currently exist:"
    docker ps -a --format '  {{.Names}}  ({{.Image}}, {{.Status}})'
fi
if ! $assume_yes; then
    read -r -p "Continue? [y/N] " reply
    [[ $reply =~ ^[yY] ]] || { echo "Stopped; nothing was changed."; exit 0; }
fi
docker system prune -af
docker builder prune -af
echo

# --------------------------------------------------- 2. decide where data goes
move_data=false
if [[ ! -d "$target_parent" ]]; then
    echo "$target_parent doesn't exist, so Docker's data stays on /."
else
    type=$(fs_type "$target_parent")
    root_free=$(avail_bytes /)
    target_free=$(avail_bytes "$target_parent")
    echo "Free now:  /  $(human "$root_free")    $target_parent  $(human "$target_free") ($type)"
    case "$type" in
        ext4|ext3|xfs|btrfs)
            if (( target_free > root_free )); then
                move_data=true
            else
                echo "/ has at least as much free space, so Docker's data stays on /."
            fi
            ;;
        *)
            echo "$target_parent is $type, which Docker can't store images on; data stays on /."
            ;;
    esac
fi
echo

# ------------------------------------------------------ 3. edit daemon.json
mkdir -p /etc/docker
if [[ -f $daemon_json ]]; then
    backup="$daemon_json.bak.$(date +%Y%m%d-%H%M%S)"
    cp -p "$daemon_json" "$backup"
    echo "Backed up $daemon_json to $backup"
fi
if $move_data; then
    mkdir -p "$target"
fi

MOVE_DATA=$move_data TARGET=$target DAEMON_JSON=$daemon_json python3 - <<'EOF'
import json, os

path = os.environ["DAEMON_JSON"]
try:
    with open(path) as f:
        text = f.read().strip()
    config = json.loads(text) if text else {}
except FileNotFoundError:
    config = {}

config.setdefault("features", {})["containerd-snapshotter"] = False
if os.environ["MOVE_DATA"] == "true":
    config["data-root"] = os.environ["TARGET"]

with open(path, "w") as f:
    json.dump(config, f, indent=4)
    f.write("\n")
EOF

echo "New $daemon_json:"
cat "$daemon_json"
echo

# ------------------------------------------------------------- 4. restart
echo "Restarting Docker..."
if ! systemctl restart docker; then
    echo "Docker failed to restart. Check: journalctl -u docker -n 50" >&2
    [[ -n "${backup:-}" ]] && echo "To undo: sudo cp $backup $daemon_json && sudo systemctl restart docker" >&2
    exit 1
fi

echo
echo "== Result =="
docker info 2>/dev/null | grep -E "Docker Root Dir|Storage Driver|Runtimes" || true
df -h / "$target_parent" 2>/dev/null || df -h /
echo
echo "Done. Now rebuild as your normal user (no sudo), from the bridge_data_robot-main folder:"
echo '  USB_CONNECTOR_CHART=$(pwd)/usb_connector_chart.yml docker compose up --build robonet'
