# Rules Lawyer Bot

A Discord bot that answers tabletop rules questions with **Claude** (Anthropic), rudely, on purpose. Ask with the slash command:

```
/rules system:<game> question:<text>
```

| System | Source |
|---|---|
| D&D 5e (2024) | Claude's knowledge only |
| Mothership 1e | `refs/mothership.md` (Player's Survival Guide v1.2) |
| Cyberpunk RED | `refs/cyberpunk-red.md` (core rulebook) |

A system's reference is sent with every question (no prompt caching: questions
are one-offs). Answers cite `[p. N]` pages only from the reference. Systems are
defined in `rules_lawyer/systems.py`; adding one is an entry there plus,
optionally, `refs/<id>.md`.

## Requirements

- Python 3.12 (the image pins `python:3.12.15-slim-bookworm`)
- [Discord application](https://discord.com/developers/applications) with a bot token
- [Anthropic API key](https://console.anthropic.com/)

### Discord settings

No privileged intents are needed. Invite the bot with **both** the `bot` and `applications.commands` scopes (re-inviting an existing bot with the extra scope doesn't kick it).

## Environment variables

| Variable | Purpose |
|----------|---------|
| `DISCORD_BOT_TOKEN` | Discord bot token |
| `ANTHROPIC_API_KEY` | Claude API key |
| `RULES_LAWYER_MODEL` | Optional. Defaults to `claude-sonnet-5-5` |
| `REFS_DIR` | Optional. Where `<system>.md` references are read at startup. Defaults to `/refs` |
| `RULES_LAWYER_SYNC_COMMANDS` | Set to `1` for one run to register `/rules` with Discord. Do this after deploying a change to the command (e.g. a new system), never permanently: global command writes are rate-limited |

Each Claude call logs one line: the system, the model that answered (a refusal can fall back to another model), the stop reason, and token use.

## Run locally

Run only one instance per bot token.

```bash
uv venv -p 3.12 .venv && uv pip install -p .venv -r requirements.txt
export DISCORD_BOT_TOKEN="..." ANTHROPIC_API_KEY="..." REFS_DIR=refs
.venv/bin/python -m rules_lawyer.main
```

To try a question without Discord (e.g. while tuning a reference):

```bash
.venv/bin/python -m rules_lawyer.cli --system mothership "How does armor work?"
```

## References

`refs/` is gitignored: the references are transcribed from purchased books and
never enter git. They're hand-curated, rules-only Markdown with `[p. N]`
printed-page markers, not raw PDF extracts (the PDFs' tables don't extract
cleanly). On the box they live in `/var/srv/ruleslawyer/refs/`, mounted
read-only at `/refs`; see local-config for refreshing them.

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
| `rules_lawyer/main.py` | Discord client and the `/rules` command |
| `rules_lawyer/cli.py` | One question from the command line |
| `rules_lawyer/systems.py` | Supported systems and their edition notes |
| `rules_lawyer/refs.py` | Loads `refs/<system>.md` at startup |
| `rules_lawyer/prompt.py` | Rules-lawyer prompt |
| `rules_lawyer/claude.py` | Anthropic client, request and usage logging |
| `scripts/deploy-minipc.sh` | Build on minipc and restart |
