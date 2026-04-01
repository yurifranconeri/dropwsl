test -f "${1}/.pre-commit-config.yaml" 2>/dev/null && grep -q 'gitleaks' "${1}/.pre-commit-config.yaml" 2>/dev/null
