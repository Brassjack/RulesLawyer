#!/usr/bin/env bash
#
# Install the Rules Lawyer bot as a systemd service using a local venv (no Docker).
#
# Usage:
#   sudo ./install-python-service.sh [--source-dir /path/to/RulesLawyerBot] [--env-file /path] [--run-as-root]
#
# Expects python3 on PATH. Creates /opt/rules-lawyer-bot/{app,venv}, secrets in /etc/rules-lawyer-bot/bot.env
# Service unit: rules-lawyer-bot-python.service
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SOURCE="$(cd "$SCRIPT_DIR/../.." && pwd)"

SOURCE_DIR="$DEFAULT_SOURCE"
ENV_FILE_SRC=""
RUN_AS_ROOT="false"
UNIT_NAME="rules-lawyer-bot-python.service"
UNIT_SRC="$SCRIPT_DIR/rules-lawyer-bot-python.service"
UNIT_DST="/etc/systemd/system/$UNIT_NAME"
ETC_DIR="/etc/rules-lawyer-bot"
DOC_DIR="/usr/local/share/doc/rules-lawyer-bot"
PREFIX="/opt/rules-lawyer-bot"
APP="$PREFIX/app"
VENV="$PREFIX/venv"
SERVICE_USER="ruleslawyer"

usage() {
  sed -n '1,18p' "$0" | tail -n +2
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-dir)
      SOURCE_DIR="${2:?}"
      shift 2
      ;;
    --env-file)
      ENV_FILE_SRC="${2:?}"
      shift 2
      ;;
    --run-as-root)
      RUN_AS_ROOT="true"
      shift
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

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is not installed or not on PATH." >&2
  exit 1
fi

if [[ ! -d "$SOURCE_DIR/rules_lawyer" ]] || [[ ! -f "$SOURCE_DIR/requirements.txt" ]]; then
  echo "Source dir must contain rules_lawyer/ and requirements.txt (got: $SOURCE_DIR)" >&2
  exit 1
fi

mkdir -p "$ETC_DIR" "$DOC_DIR" "$APP"
chmod 700 "$ETC_DIR"

if [[ "$RUN_AS_ROOT" != "true" ]]; then
  if ! id -u "$SERVICE_USER" >/dev/null 2>&1; then
    useradd --system --home-dir "$PREFIX" --shell /usr/sbin/nologin "$SERVICE_USER"
  fi
fi

rm -rf "$APP/rules_lawyer" "$VENV"
mkdir -p "$APP"
cp -a "$SOURCE_DIR/rules_lawyer" "$APP/"
cp -a "$SOURCE_DIR/requirements.txt" "$APP/"

python3 -m venv "$VENV"
"$VENV/bin/pip" install --upgrade pip -q
"$VENV/bin/pip" install -r "$APP/requirements.txt"

if [[ -n "$ENV_FILE_SRC" ]]; then
  install -m 600 "$ENV_FILE_SRC" "$ETC_DIR/bot.env"
elif [[ ! -f "$ETC_DIR/bot.env" ]]; then
  install -m 600 "$SCRIPT_DIR/bot.env.example" "$ETC_DIR/bot.env"
fi

if [[ "$RUN_AS_ROOT" == "true" ]]; then
  chown -R root:root "$PREFIX"
  chmod 600 "$ETC_DIR/bot.env"
else
  chown -R "$SERVICE_USER:$SERVICE_USER" "$PREFIX"
  chown root:"$SERVICE_USER" "$ETC_DIR/bot.env"
  chmod 640 "$ETC_DIR/bot.env"
fi

TMP_UNIT="$(mktemp)"
if [[ "$RUN_AS_ROOT" == "true" ]]; then
  awk '
    /^# RUN_AS_USER_DIRECTIVES$/ { next }
    { print }
  ' "$UNIT_SRC" >"$TMP_UNIT"
else
  awk -v u="$SERVICE_USER" '
    /^# RUN_AS_USER_DIRECTIVES$/ {
      print "User=" u
      print "Group=" u
      next
    }
    { print }
  ' "$UNIT_SRC" >"$TMP_UNIT"
fi
install -m 644 "$TMP_UNIT" "$UNIT_DST"
rm -f "$TMP_UNIT"

cat >"$DOC_DIR/python-ec2-service.txt" <<EOF
Native Python install: $PREFIX
Secrets: $ETC_DIR/bot.env
Unit: $UNIT_DST

Commands:
  sudo systemctl status $UNIT_NAME
  sudo journalctl -u $UNIT_NAME -f
  sudo systemctl restart $UNIT_NAME

Reinstall after code changes: re-run install-python-service.sh with the same --source-dir (overwrites app, recreates venv pip install).
EOF

systemctl daemon-reload

echo "Installed $UNIT_DST"
echo "Secrets: $ETC_DIR/bot.env"
if [[ ! -s "$ETC_DIR/bot.env" ]] || grep -q 'your-discord-bot-token' "$ETC_DIR/bot.env" 2>/dev/null; then
  echo "Edit $ETC_DIR/bot.env with real DISCORD_BOT_TOKEN and ANTHROPIC_API_KEY, then:"
fi
echo "  sudo systemctl enable --now $UNIT_NAME"
