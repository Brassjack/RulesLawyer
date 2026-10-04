#!/usr/bin/env bash
# Variables in ssh command strings are meant to expand here, on the Mac.
# shellcheck disable=SC2029
#
# Build the bot image on minipc from the committed tree, then restart the
# service, but only if the deployed unit already pins this build.
#
# The unit's source of truth is local-config/minipc/apps/ruleslawyer/.
# Restarting against a stale Image= would silently keep the old image and look
# like success (goon-ai's lesson), so the pin is checked on the box itself.
set -euo pipefail

M="${M:-bazzite@192.168.0.137}"
# Relative to the remote home: ssh commands start there.
UNIT=.config/containers/systemd/ruleslawyer/ruleslawyer.container
SYSTEMCTL='export XDG_RUNTIME_DIR=/run/user/1000; systemctl --user'

cd "$(git rev-parse --show-toplevel)"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Uncommitted changes: commit first, only committed code ships." >&2
  exit 1
fi

SHA=$(git rev-parse --short HEAD)
TAG="localhost/rules-lawyer-bot:$SHA"

TMP=$(ssh "$M" mktemp -d)
trap 'ssh "$M" "rm -rf $TMP"' EXIT

echo "Building $TAG on $M"
git archive HEAD | ssh "$M" "tar -x -C $TMP"
ssh "$M" "podman build -t $TAG $TMP"

PIN=$(ssh "$M" "grep -E '^Image=' $UNIT 2>/dev/null || true")
if [[ "$PIN" != "Image=$TAG" ]]; then
  cat >&2 <<EOF

Built $TAG, but the deployed unit pins: ${PIN:-<no unit>}
Not restarting. To deploy this build:
  1. Set Image=$TAG in local-config/minipc/apps/ruleslawyer/ruleslawyer.container
  2. scp it to $M:.config/containers/systemd/ruleslawyer/
  3. Re-run this script (the rebuild is cached)
EOF
  exit 2
fi

ssh "$M" "$SYSTEMCTL daemon-reload && $SYSTEMCTL restart ruleslawyer"
sleep 5
ssh "$M" "$SYSTEMCTL --no-pager status ruleslawyer | head -5; export XDG_RUNTIME_DIR=/run/user/1000; journalctl --user -u ruleslawyer -n 20 --no-pager"
