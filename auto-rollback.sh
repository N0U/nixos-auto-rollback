#!/bin/bash

source "./utils.sh"

if [[ $EUID -eq 0 ]]; then
    DEBUG=false
else
    DEBUG=true
fi

COMMANDS=("yq" "nix-env" "nixos-rebuild")
for cmd in "${COMMANDS[@]}"; do
  command -v "$cmd" &> /dev/null;
  if [[ $? -ne 0 ]]; then
    error "Command $cmd not found"
    if [[ "$DEBUG" = false ]]; then
      exit 1
    fi
  fi
done

DATA_FILE="data.yml"
#CONFIG_FILE="config.yml"

VERBOSE=$(getOption ".verbose" "false");
TIMEOUT=$(getOption ".timeout" "\"2m\"");
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

NETWORK_PING_TEST_ENABLE=$(getOption ".network.ping_test.enable" "false");
readarray -t NETWORK_PING_TEST_IP < <(getOption ".network.ping_test.ip[]");
NETWORK_PING_TEST_TIMEOUT=$(getOption ".network.ping_test.timeout" "5");

if [ ${#NETWORK_PING_TEST_IP[@]} -eq 0 ]; then
  NETWORK_PING_TEST_IP=("1.1.1.1" "8.8.8.8")
fi

DNS_PING_TEST_ENABLE=$(getOption ".dnsresolve.ping_test.enable" "false");
readarray -t DNS_PING_TEST_DOMAINS < <(getOption ".dnsresolve.ping_test.domains[]");
DNS_PING_TEST_TIMEOUT=$(getOption ".dnsresolve.ping_test.timeout" "5");

if [ ${#DNS_PING_TEST_DOMAINS[@]} -eq 0 ]; then
  DNS_PING_TEST_DOMAINS=("google.com")
fi

readarray -t SERVICES < <(getOption ".services[]");

if [ ! -f "$DATA_FILE" ]; then
  createData
fi

LAST_GOOD_GENERATION=$(getData ".last_good_generation");
LAST_TEST_RESULT=$(getData ".last_result");

# This script should run after all targets
# Wait a little 
sleep $TIMEOUT


updateMotd() {
  if [[ -z "$MOTD_FILE" ]]; then
    return 0
  fi
  info "Update motd..."
  local date=$(date '+%Y-%m-%d %H:%M:%S')
  local motd_text="$date
$1"
  echo "$motd_text" > "$MOTD_FILE"
}

rollbackNotify() {
  updateMotd "$1"
  setData ".last_result" "\"$1\""
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

rollback () {
  local current_generation=$(nix-env --list-generations | grep current | awk '{print $1}');
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

  if [[ -n "$rollback_generation" ]]; then
    error "Cannot find a generation to rollback"
    return 1
  fi

  log "Rolling back..."

  local rollback_cmd="sleep 10s && nixos-rebuild --switch-generation $rollback_generation"
  if [ "$ROLLBACK_REBOOT" = true ]; then
    rollback_cmd="$rollback_cmd && reboot"
  fi

  if [ "$DEBUG" = true ]; then
    echo "Run $rollback_cmd"
  else
    nohup bash -c "$rollback_cmd" > rebuild.log 2> rebuilderror.log &
  fi
  return 0
}

pingTest() {
  local timeout="$1"
  shift

  for addr in "$@"; do
    info "Ping $addr..."
    ping -c 1 -W "$timeout" "$addr" &> /dev/null
    if [[ $? -eq 0 ]]; then
      info "$addr succesfully pinged"
      return 0
    fi
  done
  return 1
}

testNetwork() {
  local -n _ref=$1
  info "Run network tests..."
  if [[ "$NETWORK_PING_TEST_ENABLE" = true ]]; then
    pingTest "$NETWORK_PING_TEST_TIMEOUT" "${NETWORK_PING_TEST_IP[@]}"
    if [[ $? -ne 0 ]]; then
      log "Network ping test failed"
      _ref="ping"
      return 1

    fi
  fi
  return 0
}

testDns() {
  local -n _ref="$1"
  info "Run dns tests..."
  if [[ "$DNS_PING_TEST_ENABLE" = true ]]; then
    pingTest "$DNS_PING_TEST_TIMEOUT" "${DNS_PING_TEST_DOMAINS[@]}"
    if [[ $? -ne 0 ]]; then
      log "Dns ping test failed"
      _ref="ping"
      return 1
    fi
  fi
  return 0
}

testServices() {
  local -n _ref=$1
  info "Run service tests..."
  for serv in "${SERVICES[@]}"; do
    systemctl is-active --quiet "$serv"
    if [[ $? -ne 0 ]]; then
      log "$serv test failed"
      _ref="$serv"
      return 1
    fi
  done
  return 0
}

onFail() {
  local notifyText

  rollback

  if [[ $? -ne 0 ]]; then
    notifyText="$1
Rollback failed"
  else
    notifyText="$1"
  fi

  rollbackNotify "$notifyText"

  exit 0
}

testNetwork TEST_RESULT
if [[ $? -ne 0 ]]; then
  onFail "Network: $TEST_RESULT test failed"
fi

testDns TEST_RESULT
if [[ $? -ne 0 ]]; then
  onFail "DNS resolve: $TEST_REULST test failed"
fi

testServices TEST_RESULT
if [[ $? -ne 0 ]]; then
  onFail "Service: $TEST_RESULT test failed"
fi

log "All tests passed"

LAST_GOOD_GENERATION=$(nix-env --list-generations | grep current | awk '{print $1}');
setData ".last_good_generation" "$LAST_GOOD_GENERATION"

log "Generation $LAST_GOOD_GENERATION saved as succesful"

if [[ -n "$LAST_TEST_RESULT" ]]; then
  info "Last test result isn't empty"
  notify "$LAST_TEST_RESULT"
  delData ".last_result" 
fi


