echo "==> Installing pre-commit hooks..."
pre-commit install 2>/dev/null || echo -e "\033[0;33m⚠ pre-commit not found -- check if requirements-dev.txt was installed correctly\033[0m"
