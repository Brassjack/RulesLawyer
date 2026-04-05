import os
import re

from anthropic import AsyncAnthropic

MODEL = "claude-sonnet-4-6"
MAX_TOKENS = 20000
TEMPERATURE = 1.0


def _extract_answer_text(raw: str) -> str:
    """Prefer content inside <answer>...</answer> if present."""
    m = re.search(r"<answer>([\s\S]*?)</answer>", raw, re.IGNORECASE)
    if m:
        return m.group(1).strip()
    return raw.strip()


def extract_text_from_message(message) -> str:
    parts: list[str] = []
    for block in message.content:
        if hasattr(block, "text"):
            parts.append(block.text)
    return "".join(parts)


async def query_rules_lawyer(user_prompt: str) -> str:
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise RuntimeError("ANTHROPIC_API_KEY is not set")

    client = AsyncAnthropic(api_key=api_key)
    response = await client.messages.create(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        temperature=TEMPERATURE,
        messages=[
            {
                "role": "user",
                "content": [{"type": "text", "text": user_prompt}],
            }
        ],
        thinking={"type": "disabled"},
    )
    raw = extract_text_from_message(response)
    return _extract_answer_text(raw)
