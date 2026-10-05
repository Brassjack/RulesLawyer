import logging
import os
import re

from anthropic import AsyncAnthropic

MODEL = os.environ.get("RULES_LAWYER_MODEL", "claude-sonnet-5-5")
# Answers are short; this caps the cost of a runaway reply.
MAX_TOKENS = 4096
# "low" gave the 2014 bonus-action spell rule for a 2024 question at deploy.
EFFORT = "medium"
# On a policy decline, the API re-runs the request on a fallback model it picks.
FALLBACK_BETA = "server-side-fallback-2026-07-01"

REFUSAL_REPLY = "I can't answer that one."

log = logging.getLogger(__name__)

_client: AsyncAnthropic | None = None


def _get_client() -> AsyncAnthropic:
    """One client for the process, created on first use so importing needs no key.

    timeout/max_retries are kept short so a failed call reports back long before
    a Discord interaction token (15 min) would expire.
    """
    global _client
    if _client is None:
        if not os.environ.get("ANTHROPIC_API_KEY"):
            raise RuntimeError("ANTHROPIC_API_KEY is not set")
        _client = AsyncAnthropic(timeout=120, max_retries=1)
    return _client


def _extract_answer_text(raw: str) -> str:
    """Prefer content inside <answer>...</answer> if present."""
    m = re.search(r"<answer>([\s\S]*?)</answer>", raw, re.IGNORECASE)
    if m:
        return m.group(1).strip()
    return raw.strip()


def extract_text_from_message(message) -> str:
    parts: list[str] = []
    for block in message.content:
        if block.type == "text":
            parts.append(block.text)
    return "".join(parts)


def _log_usage(response) -> None:
    usage = response.usage
    fallback = any(
        entry.type == "fallback_message" for entry in (usage.iterations or [])
    )
    log.info(
        "model=%s fallback=%s stop=%s in=%s out=%s cache_read=%s cache_write=%s",
        response.model,
        fallback,
        response.stop_reason,
        usage.input_tokens,
        usage.output_tokens,
        usage.cache_read_input_tokens,
        usage.cache_creation_input_tokens,
    )


async def query_rules_lawyer(user_prompt: str) -> str:
    response = await _get_client().beta.messages.create(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        output_config={"effort": EFFORT},
        betas=[FALLBACK_BETA],
        fallbacks="default",
        messages=[
            {
                "role": "user",
                "content": [{"type": "text", "text": user_prompt}],
            }
        ],
    )
    _log_usage(response)
    if response.stop_reason == "refusal":
        log.warning("refused: %s", response.stop_details)
        return REFUSAL_REPLY
    raw = extract_text_from_message(response)
    return _extract_answer_text(raw)
