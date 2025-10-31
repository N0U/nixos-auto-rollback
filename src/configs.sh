
VERBOSE=$(getOption ".verbose" "false");
TIMEOUT=$(getOption ".timeout" "300");
MOTD_FILE=$(getOption ".notify.motd");

ROLLBACK_REBOOT=$(getOption ".rollback.reboot" "false");
ROLLBACK_GENERATION=$(getOption ".rollback.generation");

if [[ -n "$ROLLBACK_GENERATION" ]]; then
  GENERATION_EXIST=$(nix-env --list-generations | awk '{print $1}' | grep "$ROLLBACK_GENERATION");
if [[ "$GENERATION_EXIST" != "$ROLLBACK_GENERATION" ]]; then
    error "Rollback generation $ROLLBACK_GENERATION doesn't exist"
    unset ROLLBACK_GENERATION
  fi
fi

NETWORK_ENABLE=$(getOption ".network" "false");
RESOLVE_ENABLE=$(getOption ".resolve" "false");

# PING_TEST_ENABLE=$(getOption ".ping_test.enable" "false");
PING_TEST_TIMEOUT=$(getOption ".ping_test.timeout" "5");
readarray -t PING_TEST_ADDRS < <(getOption ".ping_test.addrs[]");
if [ ${#PING_TEST_ADDRS[@]} -ne 0 ]; then
  PING_TEST_ADDRS_ENABLE=true
  # PING_TEST_ADDRS=("1.1.1.1" "8.8.8.8")
fi
readarray -t PING_TEST_DOMAINS < <(getOption ".ping_test.domains[]");
if [ ${#PING_TEST_DOMAINS[@]} -ne 0 ]; then
  PING_TEST_DOMAINS_ENABLE=true
  # PING_TEST_DOMAINS =("google.com")
fi

SSHD_ENABLE=$(getOption ".sshd" "false");

# ECHO_TEST_ENABLE=$(getOption ".echo_test.enable" "false");
ECHO_TEST_IP_SERVICE=$(getOption ".echo_test.ip_service" "\"https://api.ipify.org\"");
ECHO_TEST_TIMEOUT=$(getOption ".echo_test.timeout" "5");
ECHO_PORTS=$(getOption ".echo_test.ports[]");

if [ ${#ECHO_PORTS[@]} -ne 0 ]; then
  ECHO_TEST_ENABLE=true
fi

readarray -t SERVICES < <(getOption ".services[]");
