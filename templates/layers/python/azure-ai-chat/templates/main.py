"""Azure AI Chat — send messages via Responses API."""

import logging
import os

from foundry.client import get_openai_client

from chat.responses import send_message

logging.basicConfig(level=logging.WARNING)


def main() -> None:
    model = os.environ.get("AZURE_AI_CHAT_MODEL", "")
    if not model:
        print("AZURE_AI_CHAT_MODEL not set.")
        print(
            "\nSet it to a chat-capable deployment name:\n"
            '  export AZURE_AI_CHAT_MODEL="gpt-4.1"'
        )
        print(
            "\nDiscover available models:\n"
            "  curl http://localhost:8000/api/models"
        )
        return

    print(f"Model: {model}")
    print("Type a message (Ctrl+C to quit):\n")

    previous_id: str | None = None
    try:
        while True:
            user_input = input("You: ").strip()
            if not user_input:
                continue

            result = send_message(
                user_input,
                model=model,
                previous_response_id=previous_id,
            )
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


if __name__ == "__main__":
    main()
