#!/usr/bin/env bash
#
# Install the Rules Lawyer bot as a systemd service on EC2 (or any host with Docker).
#
# Usage:
#   sudo ./install-docker-service.sh --image <full-image-uri> [--ecr-login] [--region <aws-region>] [--pull]
#
# After install, edit /etc/rules-lawyer-bot/bot.env if you did not pass --env-file, then:
#   sudo systemctl enable --now rules-lawyer-bot
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ETC_DIR="/etc/rules-lawyer-bot"
UNIT_NAME="rules-lawyer-bot.service"
RUNNER_SRC="$SCRIPT_DIR/rules-lawyer-bot-docker-run"
RUNNER_DST="/usr/local/bin/rules-lawyer-bot-docker-run"
UNIT_SRC="$SCRIPT_DIR/rules-lawyer-bot.service"
UNIT_DST="/etc/systemd/system/$UNIT_NAME"
DOC_DIR="/usr/local/share/doc/rules-lawyer-bot"

IMAGE_URI=""
ECR_LOGIN="false"
AWS_REGION="${AWS_REGION:-us-east-1}"
PULL_BEFORE_RUN="false"
ENV_FILE_SRC=""

usage() {
  sed -n '1,20p' "$0" | tail -n +2
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      IMAGE_URI="${2:?}"
      shift 2
      ;;
    --ecr-login)
      ECR_LOGIN="true"
      shift
      ;;
    --region)
      AWS_REGION="${2:?}"
      shift 2
      ;;
    --pull)
      PULL_BEFORE_RUN="true"
      shift
      ;;
    --env-file)
      ENV_FILE_SRC="${2:?}"
      shift 2
      ;;
    -h|--help)
      usage 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage 1
      ;;
  esac
done

if [[ "${EUID:-0}" -ne 0 ]]; then
  echo "Run as root (sudo)." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed or not on PATH." >&2
  exit 1
fi

mkdir -p "$ETC_DIR" "$DOC_DIR"
chmod 700 "$ETC_DIR"

if [[ -z "$IMAGE_URI" ]]; then
  if [[ -f "$ETC_DIR/config" ]]; then
    echo "Using existing $ETC_DIR/config"
  else
    echo "Pass --image <full-uri:tag> or create $ETC_DIR/config with IMAGE_URI=..." >&2
    exit 1
  fi
else
  umask 077
  {
    echo "IMAGE_URI=$IMAGE_URI"
    echo "AWS_REGION=$AWS_REGION"
    echo "ECR_LOGIN=$ECR_LOGIN"
    echo "PULL_BEFORE_RUN=$PULL_BEFORE_RUN"
  } >"$ETC_DIR/config"
  chmod 600 "$ETC_DIR/config"
fi

if [[ -n "$ENV_FILE_SRC" ]]; then
  install -m 600 "$ENV_FILE_SRC" "$ETC_DIR/bot.env"
elif [[ ! -f "$ETC_DIR/bot.env" ]]; then
  install -m 600 "$SCRIPT_DIR/bot.env.example" "$ETC_DIR/bot.env"
  echo "Created $ETC_DIR/bot.env from bot.env.example — edit it with real secrets, then:"
  echo "  sudo systemctl enable --now $UNIT_NAME"
fi

install -m 755 "$RUNNER_SRC" "$RUNNER_DST"
install -m 644 "$UNIT_SRC" "$UNIT_DST"

cat >"$DOC_DIR/ec2-service.txt" <<EOF
Config: $ETC_DIR/config
Secrets: $ETC_DIR/bot.env (chmod 600)

Commands:
  sudo systemctl status $UNIT_NAME
  sudo journalctl -u $UNIT_NAME -f
  sudo systemctl restart $UNIT_NAME

Build image locally instead of ECR:
  (from repo) docker build -t rules-lawyer-bot:local $REPO_ROOT
Then set IMAGE_URI=rules-lawyer-bot:local and ECR_LOGIN=false in $ETC_DIR/config
EOF

systemctl daemon-reload

echo "Installed $UNIT_DST and $RUNNER_DST"
echo "If bot.env was just created from the example, edit $ETC_DIR/bot.env before starting."
echo "Then: sudo systemctl enable --now $UNIT_NAME"
