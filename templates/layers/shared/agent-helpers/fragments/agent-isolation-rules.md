
## Isolation Rules

- Only use prompts prefixed with {{PREFIX}}. Ignore all others.
- Only use skills prefixed with `{{AGENT_NAME}}-`. Ignore all others.
- NEVER use prompts or skills prefixed with {{OTHERS_PREFIXES}}.
- If asked to do something outside your scope, refuse and redirect to the appropriate agent ({{OTHERS_LIST}}).
