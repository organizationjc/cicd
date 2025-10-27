#!/usr/bin/env bash
set -euo pipefail

# --- Inputs ---
if [[ $# -lt 1 || -z "${1:-}" ]]; then
  echo "Error: Se requiere 'pipeline_profile' como primer argumento." >&2
  exit 1
fi

PROFILE_NAME="$1"
RAW_EXTRA="${2:-}"

# Normaliza extra-vars:
# - vacío -> {}
# - quita comillas envolventes '...' o "..."
# - intenta corregir un '}' sobrante al final si falla jq la primera vez
normalize_extra() {
  local s="$1"
  [[ -z "$s" || "$s" == "''" || "$s" == '""' ]] && { echo '{}'; return; }

  # elimina comillas envolventes simples o dobles
  if [[ ( "$s" == \'*\' && "$s" == *\' ) || ( "$s" == \"*\" && "$s" == *\" ) ]]; then
    s="${s:1:${#s}-2}"
  fi
  echo "$s"
}

EXTRA_VARS="$(normalize_extra "$RAW_EXTRA")"

# Si jq no lo acepta, intenta quitar una llave final extra (caso común: '{}}')
if ! printf '%s' "$EXTRA_VARS" | jq -e . >/dev/null 2>&1; then
  if [[ "$EXTRA_VARS" == *'}}' ]]; then
    CANDIDATE="${EXTRA_VARS%}"}   # quita una llave al final
    if printf '%s' "$CANDIDATE" | jq -e . >/dev/null 2>&1; then
      EXTRA_VARS="$CANDIDATE"
    fi
  fi
fi

# Validación final de JSON
if ! printf '%s' "$EXTRA_VARS" | jq -e . >/dev/null 2>&1; then
  echo "Error: 'extra-vars' no es JSON válido: $EXTRA_VARS" >&2
  exit 3
fi

# --- Rutas relativas al script ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILES_DIR="${SCRIPT_DIR}/../profiles"
CONFIG_FILE="${PROFILES_DIR}/${PROFILE_NAME}.json"

# --- Validaciones ---
command -v jq >/dev/null 2>&1 || { echo "Error: 'jq' no está instalado." >&2; exit 2; }
[[ -f "$CONFIG_FILE" ]] || { echo "Error: Archivo de perfil no encontrado en $CONFIG_FILE" >&2; exit 1; }

# --- Merge ---
JSON_CONFIG="$(jq -c . "$CONFIG_FILE")"
MERGED_CONFIG="$(jq -cn --argjson base "$JSON_CONFIG" --argjson overrides "$EXTRA_VARS" '$base + $overrides')"

PROFILE_TYPE="$(printf '%s' "$MERGED_CONFIG" | jq -r .profile_type)"
case "$PROFILE_TYPE" in
  java-service-k8s|java-war-tomcat|java-lib-release) ;;
  *) echo "Error: 'profile_type' inválido ('$PROFILE_TYPE') en el perfil." >&2; exit 64;;
esac

echo "$MERGED_CONFIG"
