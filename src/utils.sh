createYq() {
  yq -n > "$1"
}

getYq() {
  local result
  if [[ -z "$3" ]]; then
    result=$(yq -r "$2" "$1");
  else
    result=$(yq -r "$2 // $3" "$1");
  fi
  echo "$result"
}

setYq() {
  echo $(yq -i "$2 = $3" "$1");
}

delYq() {
  yq -iy "del($2)" $1
}

getOption() {
  getYq "$CONFIG_FILE" "$1" "$2"
}

createData() {
  createYq "$DATA_FILE"
}

getData() {
  getYq "$DATA_FILE" "$1" "$2"
}

setData() {
  setYq "$DATA_FILE" "$1" "$2"
}

delData() {
  delYq "$DATA_FILE" "$1"
}

info() {
  if [ "$VERBOSE" = false ]; then
    return 0
  fi
  echo $1
}

log() {
  echo $1
}

error() {
  echo $1 >&2
}

isServiceActive() {
  systemctl is-active --quiet "$1"
  return $?
}

listGenerations() {
  "$NIXOS_REBUILD" list-generations | sed '1d'
}

findGenerations() {
  "$NIXOS_REBUILD" list-generations | sed '1d' | awk '$1 == val { print $1 }' "val=$1"
}

getCurrentGeneration() {
  "$NIXOS_REBUILD" list-generations | sed '1d' | awk '$NF == "True" { print $1 }'
}
