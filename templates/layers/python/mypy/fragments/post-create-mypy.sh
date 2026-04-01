echo "==> Checking types (mypy)..."
mypy . --ignore-missing-imports --no-error-summary || echo -e "\033[0;31m⚠ Type errors found -- run 'mypy .' for details\033[0m"
