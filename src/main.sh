#!/bin/bash

NIXOS_REBUILD="/run/current-system/sw/bin/nixos-rebuild"

# Get the directory of the current script
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"


if [[ $EUID -eq 0 ]]; then
  DEBUG=false
  # if [[ "$1" != "--daemonize" ]]; then
    # nohup "$0" --daemonize >"$DATA_DIR/log" 2>"$DATA_DIR/err" </dev/null &
    # exit $?
  # fi
else
  DEBUG=true
fi

source "$SCRIPT_DIR/utils.sh"

COMMANDS=("yq" "awk" "sed")
for cmd in "${COMMANDS[@]}"; do
  command -v "$cmd" &> /dev/null;
  if [[ $? -ne 0 ]]; then
    error "Command $cmd not found"
    if [[ "$DEBUG" = false ]]; then
      exit 1
    fi
  fi
done

if [[ -z "$CONFIG_FILE" ]]; then
  error "CONFIG_FILE is undefined"
  exit 1
fi

if [[ -z "$DATA_DIR" ]]; then
  error "DATA_DIR is undefined"
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  error "Config file $CONFIG_FILE doesn't exist"
  exit 1
fi

DATA_FILE="$DATA_DIR/data.json"
RESULTS_FILE="$DATA_DIR/results.log"

source "$SCRIPT_DIR/configs.sh"

if [ ! -f "$DATA_FILE" ]; then
  createData
fi

LAST_GOOD_GENERATION=$(getData ".last_good_generation");
LAST_TEST_RESULT=$(getData ".last_result");

# This script should run after all targets
# Wait a little
sleep "${TIMEOUT}s"

updateMotd() {
  if [[ -z "$MOTD_FILE" ]]; then
    return 0
  fi
  if [ ! -f "$MOTD_FILE" ]; then
    error "Motd file $MOTD_FILE doesn't exist"
    return 1
  fi
  info "Update motd..."
  echo "$1" > "$MOTD_FILE"
}

rollbackNotify() {
  updateMotd "$1"
  echo "$1" >> "$RESULTS_FILE"
}

notify() {
  info "$1"
}

execDbg() {
  if [ "$DEBUG" = true ]; then
    echo "Run $1"
  else
    $1
  fi
}

runPingTest() {
  local timeout="$1"
  shift

  for addr in "$@"; do
    info "Ping $addr..."
    ping -c 1 -W "$timeout" "$addr" &> /dev/null
    if [[ $? -eq 0 ]]; then
      info "$addr responded"
      return 0
    fi
  done
  return 1
}

declare -A RESULTS

networkTest() {
  info "Checking network-online.target status..."
  isServiceActive "network-online.target"
  RESULTS["network-online.target"]=$?
}

resolverTest() {
  info "Checking systemd.resolver.service status..."
  isServiceActive "systemd-resolved.service"
  RESULTS["systemd.resolver.service"]=$?
}

pingAddrsTest() {
  info "Run ping test for ip addesses..."
  runPingTest "$PING_TEST_TIMEOUT" "${PING_TEST_ADDRS[@]}"
  RESULTS["ping-test-1"]=$?
}

pingDomainsTest() {
  info "Run ping test for domains..."
  runPingTest "$PING_TEST_TIMEOUT" "${PING_TEST_DOMAINS[@]}"
  RESULTS["ping-test-2"]=$?
}

sshdTest() {
  info "Checking sshd.service status..."
  isServiceActive "sshd.service"
  RESULTS["sshd.service"]=$?

  # info "Checking sshd.socket status..."
  # isServiceActive "sshd.socket"
  # RESULTS["sshd.socket"]=$?
}

echoTest() {
  info "Determining public IP address..."
  local myIp = $(curl -s --max-time "$ECHO_TEST_TIMEOUT" "$ECHO_TEST_IP_SERVICE");
  if [[ $? -ne 0 ]]; then
    error "Could not determine public IP address"
    RESULTS["echo"]=$?
    return 1
  fi

  info "Run echo test for $myIp..."
  for port in "${ECHO_TEST_PORTS[@]}"; do
    timeout "$ECHO_TEST_TIMEOUT" bash -c ">/dev/tcp/$myIp/$port"
    RESULTS["echo:$port"]=$?
  done
  return 0
}

servicesTest() {
  info "Run service tests..."
  for serv in "${SERVICES[@]}"; do
    isServiceActive "$serv"
    RESULTS["$serv"]=$?
  done
}

rollback () {
  local current_generation=$(getCurrentGeneration);
  local rollback_generation

  if [[ -n "$ROLLBACK_GENERATION" ]]; then
    rollback_generation="$ROLLBACK_GENERATION"
  else
    rollback_generation="$LAST_GOOD_GENERATION"
  fi

  if [[ "$rollback_generation" = "$current_generation" ]]; then
    error "Cannot rollback due to current generation $current_generation is a rollback target $rollback_generation"
    return 1
  fi

  if [[ -z "$rollback_generation" ]]; then
    error "Cannot find a generation to rollback"
    return 1
  fi

  log "Rolling back..."

  ROLLBACK_TO="$rollback_generation"

  local rollback_cmd="sleep 10s && $NIXOS_REBUILD swtich --switch-generation $rollback_generation"
  if [ "$ROLLBACK_REBOOT" = true ]; then
    rollback_cmd="$rollback_cmd && reboot"
  fi

  if [ "$DEBUG" = true ]; then
    echo "Run $rollback_cmd"
  else
    nohup bash -c "$rollback_cmd" > "$DATA_DIR/rebuild.log" 2> "$DATA_DIR/rebuilderror.log" &
  fi
  return 0
}

handleFailure() {
  rollback
  if [[ $? -ne 0 ]]; then
    error "Rollback failed"
    LOG+=$'\n'"Rollback failed"
  else
    log "System rolled back to $ROLLBACK_TO generation"
    LOG+=$'\n'"System rolled back to $ROLLBACK_TO generation"
  fi

  rollbackNotify "$LOG"
  exit 0
}

if [[ "$NETWORK_ENABLE" = true ]]; then
  networkTest
fi

if [[ "$RESOLVE_ENABLE" = true ]]; then
  resolverTest
fi

if [[ "$PING_TEST_ADDRS_ENABLE" = true ]]; then
  pingAddrsTest
fi

if [[ "$PING_TEST_DOMAINS_ENABLE" = true ]]; then
  pingDomainsTest
fi

if [[ "$SSHD_ENABLE" = true ]]; then
  sshdTest
fi

if [[ -n "$SERVICES" ]]; then
  testServices
fi

TESTS_FAILED=false

DATE=$(date '+%Y-%m-%d %H:%M:%S')
LOG="============  Auto rollback-service =================="
LOG+=$'\n'"---- $DATE ----"

for key in ${!RESULTS[@]}; do
  res="${RESULTS[${key}]}"
  if [ "$res" -eq 0 ]; then
    msg="$key - ✓ PASS"
  else
    msg="$key - ✗ FAIL"
    TESTS_FAILED=true
  fi
  log "$msg"
  LOG+=$'\n'"$msg"
done

if [[ "$TESTS_FAILED" = true ]]; then
  handleFailure
else
  log "All tests passed"
  LAST_GOOD_GENERATION=$(getCurrentGeneration);
  setData ".last_good_generation" "$LAST_GOOD_GENERATION"
  log "Generation $LAST_GOOD_GENERATION saved as succesful"
fi




