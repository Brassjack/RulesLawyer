# Rules Lawyer Bot

A Discord bot that answers **Dungeons & Dragons 5e (2024)** rules questions. When someone **mentions the bot** with a query, it sends the rules-lawyer prompt to **Claude** (Anthropic) and replies in the channel.

## Requirements

- Python 3.12 (the image pins `python:3.12.15-slim-bookworm`)
- [Discord application](https://discord.com/developers/applications) with a bot token
- [Anthropic API key](https://console.anthropic.com/)

### Discord settings

In the Developer Portal, under **Bot**, enable **Message Content Intent** (privileged). Invite the bot with permissions to read messages and send messages in the channels you care about.

## Environment variables

| Variable | Purpose |
|----------|---------|
| `DISCORD_BOT_TOKEN` | Discord bot token |
| `ANTHROPIC_API_KEY` | Claude API key |
| `RULES_LAWYER_MODEL` | Optional. Defaults to `claude-sonnet-5-5` |

Each Claude call logs one line: the model that answered (a refusal can fall back to another model), the stop reason, and token use.

## Run locally

Run only one instance per bot token, or every mention gets two replies.

```bash
uv venv -p 3.12 .venv && uv pip install -p .venv -r requirements.txt
export DISCORD_BOT_TOKEN="..." ANTHROPIC_API_KEY="..."
.venv/bin/python -m rules_lawyer.main
```

## Deploy: minipc

The bot runs on Jack's home mini PC as a rootless podman quadlet. The unit,
secrets layout and operations notes live in `local-config/minipc/apps/ruleslawyer/`.

```bash
scripts/deploy-minipc.sh
```

The script ships `git archive HEAD` to the box and builds
`localhost/rules-lawyer-bot:<short-sha>` there. It only restarts the service if
the deployed unit already pins that tag. Otherwise it prints the tag. In that
case, bump `Image=` in local-config, copy the unit to the box and re-run. Commit
first: the script refuses to run with uncommitted changes.

## Layout

| Path | Role |
|------|------|
| `rules_lawyer/main.py` | Discord client and mention handling |
| `rules_lawyer/prompt.py` | Rules-lawyer prompt |
| `rules_lawyer/claude.py` | Anthropic client, request and usage logging |
| `scripts/deploy-minipc.sh` | Build on minipc and restart |
