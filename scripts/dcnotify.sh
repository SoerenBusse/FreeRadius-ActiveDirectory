#!/bin/bash
# Einstellungen
LAST_WATCH_FILE="/tmp/$(cat /proc/sys/kernel/random/uuid).watch"

POSITIONAL_ARGUMENTS=()
while [[ $# -gt 0 ]]; do
  key="${1}"

  case ${key} in
  -p | --poll-time)
    POLL_TIME="${2}"
    shift
    shift
    ;;
  -d | --directory-path)
    DIRECTORY_PATH="${2}"
    shift
    shift
    ;;
  *)
    POSITIONAL_ARGUMENTS+=("${1}")
    shift
    ;;
  esac
done

if [[ -z ${POLL_TIME} || -z ${DIRECTORY_PATH} ]]; then
  echo "Missing -p|--poll-time, -d|--directory-path"
  exit 1
fi

if [[ ${#POSITIONAL_ARGUMENTS[@]} == 0 ]]; then
  echo "Missing command to execute"
  exit 1
fi

while true; do
  # Datei am Anfang anlegen, ist die Zeitreferenz
  touch "${LAST_WATCH_FILE}"

  sleep "${POLL_TIME}" &
  wait $!

  find "${DIRECTORY_PATH}" -newer "${LAST_WATCH_FILE}" | grep -q .
  found_changes=$?

  # Gab es Änderungen?
  if [[ $found_changes == 0 ]]; then
    echo "[INFO] Found changes in directory"
    # Befehl ausführen
    "${POSITIONAL_ARGUMENTS[@]}"
  else
    echo "[INFO] Found no changes in directory"
  fi
done
