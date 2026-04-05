# Rules Lawyer Bot

A Discord bot that answers **Dungeons & Dragons 5e (2024)** rules questions. When someone **mentions the bot** with a query, it sends the same prompt used by `create_message.py` to **Claude** (Anthropic) and replies in the channel.

## Requirements

- Python 3.12+ (for local or EC2 Python install)
- [Discord application](https://discord.com/developers/applications) with a bot token
- [Anthropic API key](https://console.anthropic.com/)

### Discord settings

In the Developer Portal, under **Bot**, enable **Message Content Intent** (privileged). Invite the bot with permissions to read messages and send messages in the channels you care about.

## Environment variables

| Variable | Purpose |
|----------|---------|
| `DISCORD_BOT_TOKEN` | Discord bot token |
| `ANTHROPIC_API_KEY` | Claude API key |

## Run locally

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
export DISCORD_BOT_TOKEN="..." ANTHROPIC_API_KEY="..."
.venv/bin/python -m rules_lawyer.main
```

## One-off CLI (`create_message.py`)

Uses the shared prompt module; reads `QUERY` from the environment:

```bash
export ANTHROPIC_API_KEY="..."
export QUERY="Can you cast two leveled spells in one turn?"
python create_message.py
```

## Docker

```bash
docker build -t rules-lawyer-bot .
docker run --rm -e DISCORD_BOT_TOKEN -e ANTHROPIC_API_KEY rules-lawyer-bot
```

## AWS (ECS Fargate)

Terraform provisions a default-VPC **ECR** repository, **ECS Fargate** service (one task), and **CloudWatch** logs. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` (gitignored), set tokens and region, then:

```bash
cd terraform && terraform init && terraform apply
```

Build and push the image, then roll the service:

```bash
./scripts/deploy.sh us-east-1 latest
```

The second argument is the image tag; it should match `image_tag` in Terraform if you do not use `latest`.

## EC2 (systemd, no Terraform required)

- **Container:** `scripts/ec2/install-docker-service.sh` installs `rules-lawyer-bot.service` and runs the image from ECR (or any registry). See `scripts/ec2/config.example` and `bot.env.example`.
- **Native Python:** `scripts/ec2/install-python-service.sh` installs `rules-lawyer-bot-python.service` with a venv under `/opt/rules-lawyer-bot`. Uses the same `/etc/rules-lawyer-bot/bot.env` format.

After either install, edit secrets, then `sudo systemctl enable --now <unit>`.

## Layout

| Path | Role |
|------|------|
| `rules_lawyer/main.py` | Discord client and mention handling |
| `rules_lawyer/prompt.py` | Rules-lawyer system prompt |
| `rules_lawyer/claude.py` | Async Anthropic client |
| `terraform/` | ECS + ECR + logging |
| `scripts/deploy.sh` | ECR login, build/push, ECS force deployment |
| `scripts/ec2/` | EC2 systemd installers and examples |
