#!/usr/bin/env bats
# tests/unit/test_install_wsl_vpnkit.bats -- Tests for _wsl_get_default_distro
# and _wsl_safe_import_distro from lib/core/wsl-vpnkit.sh.
#
# Stubs wsl.exe via PATH override. The stub:
#   - records every call into $STUB_LOG
#   - reads/writes the "current default" from $TEST_TEMP/wsl_default
#   - simulates the buggy WSL behavior where `--import` resets the default
#     to the newly imported distro.

setup() {
  load '../helpers/test_helper'
  _common_setup
  source "${REPO_ROOT}/lib/core/wsl-vpnkit.sh"

  STUB_DIR="${TEST_TEMP}/stub_bin"
  STUB_LOG="${TEST_TEMP}/wsl_calls.log"
  STATE_FILE="${TEST_TEMP}/wsl_default"
  mkdir -p "$STUB_DIR"
  : > "$STUB_LOG"

  cat > "${STUB_DIR}/wsl.exe" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "${STUB_LOG}"
case "\$1" in
  -l)
    if [[ "\$2" == "-v" ]]; then
      if [[ -s "${STATE_FILE}" ]]; then
        def="\$(cat "${STATE_FILE}")"
        printf '  NAME      STATE   VERSION\n* %s   Running 2\n' "\$def"
      else
        printf '  NAME      STATE   VERSION\n'
      fi
    fi
    ;;
  --import)
    # Simulates buggy WSL: --import reassigns default to the imported distro
    echo "\$2" > "${STATE_FILE}"
    ;;
  --set-default)
    echo "\$2" > "${STATE_FILE}"
    ;;
esac
exit 0
EOF
  chmod +x "${STUB_DIR}/wsl.exe"

  ORIG_PATH="$PATH"
  export PATH="${STUB_DIR}:${PATH}"
}

teardown() {
  export PATH="${ORIG_PATH:-$PATH}"
  _common_teardown
}

# ---- _wsl_get_default_distro --------------------------------------

@test "_wsl_get_default_distro: parses '* <name>' from wsl.exe -l -v" {
  echo "Ubuntu-24.04" > "$STATE_FILE"
  run _wsl_get_default_distro
  assert_success
  assert_output "Ubuntu-24.04"
}

@test "_wsl_get_default_distro: empty output when no default" {
  : > "$STATE_FILE"
  run _wsl_get_default_distro
  assert_success
  assert_output ""
}

# ---- _wsl_safe_import_distro --------------------------------------

@test "_wsl_safe_import_distro: restores previous default when --import reassigns it" {
  echo "Ubuntu-24.04" > "$STATE_FILE"

  run _wsl_safe_import_distro "wsl-vpnkit" "C:\\Users\\foo\\wsl-vpnkit" "/tmp/fake.tar"
  assert_success

  # --import was called with the right args
  run grep -F -- "--import wsl-vpnkit --version 2 C:\\Users\\foo\\wsl-vpnkit /tmp/fake.tar" "$STUB_LOG"
  assert_success

  # --set-default was called to restore
  run grep -F -- "--set-default Ubuntu-24.04" "$STUB_LOG"
  assert_success

  # And the state ended up restored
  assert_equal "$(cat "$STATE_FILE")" "Ubuntu-24.04"
}

@test "_wsl_safe_import_distro: no --set-default when previous default was already wsl-vpnkit" {
  echo "wsl-vpnkit" > "$STATE_FILE"

  run _wsl_safe_import_distro "wsl-vpnkit" "C:\\Users\\foo\\wsl-vpnkit" "/tmp/fake.tar"
  assert_success

  run grep -F -- "--set-default" "$STUB_LOG"
  assert_failure
}

@test "_wsl_safe_import_distro: no --set-default when there was no previous default" {
  : > "$STATE_FILE"

  run _wsl_safe_import_distro "wsl-vpnkit" "C:\\Users\\foo\\wsl-vpnkit" "/tmp/fake.tar"
  assert_success

  run grep -F -- "--set-default" "$STUB_LOG"
  assert_failure
}
