#!/bin/bash
# Überprüft, ob die übermittelten Environment Variabeln gesetzt sind

# Prüfen ob Dateiname gesetzt
if [[ $# == 0 ]]; then
  echo "This script requires environment names as parameters: ./${0} HELLO WOLRD"
  exit 1
fi

# Jeden erforderlichen Parameter prüfen, ob dieser gesetzt ist
for required_env in "$@"; do
  if [[ -z "${!required_env}" ]]; then
    echo "Missing environment variable ${required_env}"
    exit 1
  fi
done
