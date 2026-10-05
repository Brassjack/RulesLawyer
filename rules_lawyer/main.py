"""
Gateway bot: requires Message Content Intent (Discord Developer Portal > Bot > Privileged Gateway Intents).
"""

import logging
import os
import re
import sys

import discord

from rules_lawyer.claude import query_rules_lawyer
from rules_lawyer.prompt import build_user_prompt

# Discord message content max is 2000; leave margin for formatting.
DISCORD_MAX_LEN = 1900


def _strip_bot_mentions(content: str, message: discord.Message) -> str:
    text = content
    for m in message.mentions:
        text = re.sub(rf"<@!?{m.id}>", "", text)
    return re.sub(r"\s+", " ", text).strip()


def _chunk_text(text: str, max_len: int = DISCORD_MAX_LEN) -> list[str]:
    if not text:
        return ["(empty response)"]
    chunks: list[str] = []
    remaining = text
    while remaining:
        if len(remaining) <= max_len:
            chunks.append(remaining)
            break
        chunks.append(remaining[:max_len])
        remaining = remaining[max_len:]
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

    intents = discord.Intents.default()
    intents.message_content = True
    intents.members = False

    client = discord.Client(intents=intents)

    @client.event
    async def on_ready() -> None:
        assert client.user is not None
        logging.info("Logged in as %s (%s)", client.user, client.user.id)

    @client.event
    async def on_message(message: discord.Message) -> None:
        if message.author.bot:
            return
        if client.user is None or client.user not in message.mentions:
            return

        query = _strip_bot_mentions(message.content, message)
        if not query:
            await message.reply(
                "You pinged me with nothing? Put the actual rules question in the same message, genius.",
                mention_author=False,
            )
            return

        async with message.channel.typing():
            try:
                user_prompt = build_user_prompt(query)
                answer = await query_rules_lawyer(user_prompt)
            except Exception as e:
                logging.exception("query failed")
                await message.reply(
                    f"Something went wrong while asking Claude: `{e!s}`",
                    mention_author=False,
                )
                return

        first = True
        for part in _chunk_text(answer):
            if first:
                await message.reply(part, mention_author=False)
                first = False
            else:
                await message.channel.send(part)

    # log_handler=None: keep the logging config above instead of discord.py's own.
    client.run(token, log_handler=None)


if __name__ == "__main__":
    main()
