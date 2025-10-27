#!/usr/bin/env bash
set -euo pipefail

# --- Validar Inputs ---
if [[ $# -lt 1 || -z "${1:-}" ]]; then
  echo "Error: Se requiere 'pipeline_profile' como primer argumento." >&2
  exit 1
fi

PROFILE_NAME="$1"
EXTRA_VARS="${2:-{}}"

# --- Resolver rutas relativas al script ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# asume perfiles en ../profiles respecto al script: cicd-src/.github/scripts -> cicd-src/.github/profiles
PROFILES_DIR="$(cd "${SCRIPT_DIR}/../profiles" && pwd)"
CONFIG_FILE="${PROFILES_DIR}/${PROFILE_NAME}.json"

# --- Dependencias ---
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: 'jq' no está instalado en el runner." >&2
  exit 2
fi

# --- Lógica de Merge y Validación ---
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Archivo de perfil no encontrado en ${CONFIG_FILE}" >&2
  echo "Hint: Verifica que el repo CI/CD tenga .github/profiles/${PROFILE_NAME}.json y la ruta esperada." >&2
  exit 1
fi

# Validar que EXTRA_VARS sea JSON válido
if ! echo "$EXTRA_VARS" | jq -e . >/dev/null 2>&1; then
  echo "Error: 'extra-vars' no es JSON válido: $EXTRA_VARS" >&2
  exit 3
fi

JSON_CONFIG="$(jq -c . "$CONFIG_FILE")"
MERGED_CONFIG="$(jq -cn --argjson base "$JSON_CONFIG" --argjson overrides "$EXTRA_VARS" '$base + $overrides')"

PROFILE_TYPE="$(echo "$MERGED_CONFIG" | jq -r .profile_type)"
case "$PROFILE_TYPE" in
  java-service-k8s|java-war-tomcat|java-lib-release) ;;
  *)
    echo "Error: 'profile_type' inválido ('$PROFILE_TYPE') en el perfil." >&2
    exit 64
    ;;
esac

# --- Salida Final ---
echo "$MERGED_CONFIG"
