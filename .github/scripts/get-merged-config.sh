#!/bin/bash
set -e

# --- Validar Inputs ---
if [ -z "$1" ]; then
  echo "Error: Se requiere 'pipeline_profile' como primer argumento." >&2
  exit 1
fi

PROFILE_NAME="$1"
# Si el segundo argumento (extra-vars) está vacío, usa un JSON vacío
EXTRA_VARS=${2:-{\}} 

CONFIG_FILE=".github/profiles/${PROFILE_NAME}.json"

# --- Lógica de Merge y Validación ---
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Archivo de perfil no encontrado en $CONFIG_FILE" >&2
  exit 1
fi

JSON_CONFIG=$(jq -c . "$CONFIG_FILE")
MERGED_CONFIG=$(echo "$JSON_CONFIG" | jq -c --argjson overrides "$EXTRA_VARS" '. + $overrides')

PROFILE_TYPE=$(echo "$MERGED_CONFIG" | jq -r .profile_type)
case "$PROFILE_TYPE" in
  java-service-k8s|java-war-tomcat|java-lib-release)
    ;; # Válido
  *)
    echo "Error: 'profile_type' inválido ('$PROFILE_TYPE') en el perfil." >&2
    exit 64
    ;;
esac

# --- Salida Final ---
# El script simplemente "imprime" el JSON final.
# El YAML de Actions lo capturará desde stdout.
echo "$MERGED_CONFIG"