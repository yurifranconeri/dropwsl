echo "==> Checking Azure credentials..."
if command -v az >/dev/null 2>&1; then
  if az account show --output none 2>/dev/null; then
    echo "    Azure CLI authenticated ✔"
  else
    echo -e "\033[0;33m⚠ Not logged in to Azure. Run 'az login' to enable Azure features.\033[0m"
  fi
else
  echo -e "\033[0;33m⚠ Azure CLI not found. Azure features will use environment variables only.\033[0m"
fi
