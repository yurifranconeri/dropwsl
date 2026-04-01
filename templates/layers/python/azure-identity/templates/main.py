"""Azure Identity — credential verification and token inspection."""

import logging

from azure.core.exceptions import ClientAuthenticationError

from auth.credential import credential_health, decode_token_claims, get_credential

logging.basicConfig(level=logging.WARNING)


def main() -> None:
    credential = get_credential()
    try:
        token = credential.get_token("https://management.azure.com/.default")
        claims = decode_token_claims(token.token)
        print("Authenticated successfully.\n")
        print(f"  Name:       {claims.get('name', 'N/A')}")
        print(f"  Email:      {claims.get('upn', claims.get('unique_name', 'N/A'))}")
        print(f"  Tenant ID:  {claims.get('tid', 'N/A')}")
        print(f"  Object ID:  {claims.get('oid', 'N/A')}")
        print(f"  Expires at: {claims.get('exp_iso', 'N/A')}")
        print(f"\n  Health check: {'ok' if credential_health() else 'degraded'}")
    except ClientAuthenticationError as exc:
        print(f"Authentication failed: {exc.message}")
        print("\nRun 'az login' to authenticate, then try again.")


if __name__ == "__main__":
    main()
