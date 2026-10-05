"""Ask one question without Discord, to tune a reference before deploying.

    python -m rules_lawyer.cli --system mothership "How does armor work?"
"""

import argparse
import asyncio
import logging
import sys
from pathlib import Path

from rules_lawyer.claude import query_rules_lawyer
from rules_lawyer.prompt import build_system_prompt, build_user_prompt
from rules_lawyer.refs import load_references
from rules_lawyer.systems import SYSTEMS


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--system", required=True, choices=sorted(SYSTEMS))
    parser.add_argument("--refs-dir", type=Path, default=Path("refs"))
    parser.add_argument("question")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s", stream=sys.stderr)
    refs = load_references(args.refs_dir)
    answer = asyncio.run(
        query_rules_lawyer(
            args.system,
            build_system_prompt(SYSTEMS[args.system], refs.get(args.system)),
            build_user_prompt(args.question),
        )
    )
    print(answer)


if __name__ == "__main__":
    main()
