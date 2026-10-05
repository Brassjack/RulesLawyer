"""
Gateway bot with one slash command: /rules system:<choice> question:<text>.

Needs no privileged intents. The bot must be invited with the
applications.commands scope as well as bot.
"""

import logging
import os
import sys
from pathlib import Path

import discord
from discord import app_commands

from rules_lawyer.claude import query_rules_lawyer
from rules_lawyer.prompt import build_system_prompt, build_user_prompt
from rules_lawyer.refs import load_references
from rules_lawyer.systems import SYSTEMS

# Discord message content max is 2000; leave margin for formatting.
DISCORD_MAX_LEN = 1900


def _chunk_text(text: str, max_len: int = DISCORD_MAX_LEN) -> list[str]:
    """Split on the last newline before max_len, falling back to a hard split."""
    if not text:
        return ["(empty response)"]
    chunks: list[str] = []
    remaining = text
    while len(remaining) > max_len:
        cut = remaining.rfind("\n", 0, max_len)
        if cut <= 0:
            cut = max_len
        chunks.append(remaining[:cut])
        remaining = remaining[cut:].lstrip("\n")
    if remaining:
        chunks.append(remaining)
    return chunks


def _require_env(name: str) -> str:
    v = os.environ.get(name)
    if not v:
        print(f"Missing required environment variable: {name}", file=sys.stderr)
        sys.exit(1)
    return v


def main() -> None:
    token = _require_env("DISCORD_BOT_TOKEN")
    _require_env("ANTHROPIC_API_KEY")

    logging.basicConfig(
        level=logging.INFO,
        format="%(levelname)s %(name)s: %(message)s",
        stream=sys.stdout,
    )

    refs = load_references(Path(os.environ.get("REFS_DIR", "/refs")))
    # Global command writes are rate-limited, so only sync when asked: a crash
    # loop under systemd would otherwise burn through the limit.
    sync_commands = os.environ.get("RULES_LAWYER_SYNC_COMMANDS") == "1"

    client = discord.Client(intents=discord.Intents.default())
    tree = app_commands.CommandTree(client)

    @tree.command(name="rules", description="Ask the rules lawyer a rules question")
    @app_commands.describe(system="Which game", question="Your rules question")
    @app_commands.choices(
        system=[
            app_commands.Choice(name=system.name, value=system_id)
            for system_id, system in SYSTEMS.items()
        ]
    )
    async def rules(
        interaction: discord.Interaction,
        system: app_commands.Choice[str],
        question: app_commands.Range[str, 1, 1500],
    ) -> None:
        # Claude takes longer than Discord's 3 s window, so defer and follow up.
        await interaction.response.defer(thinking=True)
        try:
            answer = await query_rules_lawyer(
                system.value,
                build_system_prompt(SYSTEMS[system.value], refs.get(system.value)),
                build_user_prompt(question),
            )
        except Exception as e:
            logging.exception("query failed")
            await interaction.followup.send(
                f"Something went wrong while asking Claude: `{e!s}`"
            )
            return

        # The deferred reply doesn't show the options, so echo the question.
        header = f"> **{system.name}:** {question}\n\n"
        for part in _chunk_text(header + answer):
            await interaction.followup.send(part)

    @client.event
    async def setup_hook() -> None:
        if sync_commands:
            synced = await tree.sync()
            logging.info("synced %d global command(s)", len(synced))

    @client.event
    async def on_ready() -> None:
        assert client.user is not None
        logging.info("Logged in as %s (%s)", client.user, client.user.id)

    # log_handler=None: keep the logging config above instead of discord.py's own.
    client.run(token, log_handler=None)


if __name__ == "__main__":
    main()
