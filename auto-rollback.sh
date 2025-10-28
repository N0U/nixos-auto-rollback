#!/bin/bash

DATA_FILE="./data.yml"
CONFIG_FILE="config.yml"

VERBOSE=$(yq -r '.verbose // "false"' "$CONFIG_FILE");
TIMEOUT=$(yq -r '.timeout // "2m"' "$CONFIG_FILE");
MOTD_FILE=$(yq -r '.motd' "$CONFIG_FILE");

ROLLBACK_REBOOT=$(yq -r '.rollback.reboot // false' "$CONFIG_FILE");
ROLLBACK_LIMIT=$(yq -r '.rollback.limit // 5' "$CONFIG_FILE");

NETWORK_ENABLE=$(yq -r '.network.enable // false' "$CONFIG_FILE");
NETWORK_PING=$(yq -r '.network.ping // "1.1.1.1"' "$CONFIG_FILE");
NETWORK_TIMEOUT=$(yq -r '.network.timeout // 5' "$CONFIG_FILE");

SSHD=$(yq -r '.sshd // false' "$CONFIG_FILE");

if [ ! -f "$DATA_FILE" ]; then
  yq -n '.rollback_count = 0' > "$DATA_FILE"
fi

CUR_ROLLBACK_COUNT=$(yq -r '.rollback_count // 0' "$DATA_FILE")

# This script should run after all targets
# Wait a little 
sleep $TIMEOUT

info() {
  if [ "$VERBOSE" = false ]; then
    return 0
  fi
  echo $1
}

log() {
  echo $1
}

updateMotd() {
  if [[ -z "$MOTD_FILE" ]]; then
    return 0
  fi
  info "Update motd..."
  date=$(date '+%Y-%m-%d %H:%M:%S')
  MOTD_TEXT="$date
  Failed: $1
  So far $CUR_ROLLBACK_COUNT rollback happened
  "
  echo "$MOTD_TEXT" >> "$MOTD_FILE"
}

rollback () {
  if [ $CUR_ROLLBACK_COUNT -gt $ROLLBACK_LIMIT ]; then
    log "Rollback limit reached"
    return 0
  fi
  ((CUR_ROLLBACK_COUNT++))
  info "Rollback count: $CUR_ROLLBACK_COUNT"
  yq -iy ".rollback_count = $CUR_ROLLBACK_COUNT" "$DATA_FILE"
  log "Rolling back..."
  echo "...rolling back"

  if [ "$ROLLBACK_REBOOT" = true ]; then
    log "Rebooting..."
  fi
  # nixos-rebuild switch --rollback
}

testNetwork() {
  info "Testing network..."
  ping -c 1 -W "$NETWORK_TIMEOUT" "$NETWORK_PING" &> /dev/null
  return $?
}

testService() {
  systemctl is-active --quiet "$1"
  return $?
}

onFail() {
  log "Failed: $1"
  updateMotd "$1"
  rollback
  exit 0
}

if [ "$NETWORK_ENABLE" = true ]; then
  if ! testNetwork; then
    onFail "network"
  fi
fi

if [ "$SSHD" = true ]; then
  if ! testService "sshd.service"; then
    onFail "sshd"
  fi
fi

log "All tests passed"
yq -iy '.rollback_count = 0' "$DATA_FILE"
log "Rollback count reseted"
