import os
import sys

import anthropic

from rules_lawyer.prompt import build_user_prompt

# Defaults to os.environ.get("ANTHROPIC_API_KEY")
api_key = os.environ.get("ANTHROPIC_API_KEY")
if not api_key:
    print("Set ANTHROPIC_API_KEY in the environment.", file=sys.stderr)
    sys.exit(1)

client = anthropic.Anthropic(api_key=api_key)

query = os.environ.get("QUERY", "").strip()
if not query:
    print("Set QUERY to your rules question, e.g. QUERY='Can you cast two leveled spells in one turn?'", file=sys.stderr)
    sys.exit(1)

message = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=20000,
    temperature=1,
    messages=[
        {
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "text": build_user_prompt(query),
                }
            ],
        }
    ],
    thinking={
        "type": "disabled"
    },
)
print(message.content)
