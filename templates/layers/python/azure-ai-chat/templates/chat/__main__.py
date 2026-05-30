"""Runnable inspector for the Chat module.

Usage:
    python -m {{PKG_PREFIX}}chat

Validates AZURE_AI_CHAT_MODEL, sends a message via the Responses API,
and prints the reply with token usage.
"""

import logging
import os
import sys

from ._common import chat_health
from .responses import send_message

logging.basicConfig(level=logging.WARNING)


def main() -> int:
    if not chat_health():
        print("AZURE_AI_CHAT_MODEL not set.")
        print(
            "\nSet it to a chat-capable deployment name:\n"
            '  export AZURE_AI_CHAT_MODEL="gpt-4.1"'
        )
        print(
            "\nDiscover available models:\n"
            "  python -m {{PKG_PREFIX}}foundry"
        )
        return 1

    model = os.environ["AZURE_AI_CHAT_MODEL"]
    print(f"Model: {model}")
    print("Type a message (Ctrl+C to quit):\n")

    previous_id: str | None = None
    try:
        while True:
            user_input = input("You: ").strip()
            if not user_input:
                continue

            try:
                result = send_message(
                    user_input,
                    model=model,
                    previous_response_id=previous_id,
                )
            except Exception as exc:
                print(f"ERROR: {exc}\n")
                continue

            previous_id = result["response_id"]
            print(f"AI:  {result['text']}")
            tokens = result.get("usage", {})
            if tokens:
                print(
                    f"     ({tokens.get('input_tokens', 0)} in "
                    f"+ {tokens.get('output_tokens', 0)} out "
                    f"= {tokens.get('total_tokens', 0)} tokens)"
                )
            print()
    except (KeyboardInterrupt, EOFError):
        print("\nBye!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
