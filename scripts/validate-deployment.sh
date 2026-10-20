#!/usr/bin/env bash
set -euo pipefail

# Affiche une erreur et arrête le script.
fail() {
  echo "ERREUR : $*" >&2
  exit 1
}


# Détermine le mode : check par défaut, ou deploy.
MODE="${1:-check}"

case "$MODE" in
  check|deploy) ;;
  *) fail "Mode inconnu : $MODE (check ou deploy attendu)." ;;
esac

# Détermine la branche Git à contrôler.
BRANCH="${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-$(git branch --show-current)}}"

[[ -n "$BRANCH" ]] || fail "Impossible de déterminer la branche."

# Charge la configuration depuis deployment.json.
# Le fichier dédié renvoie les variables REMOTE_DIR et BASE.
CONFIG="deployment.json"
[[ -f "$CONFIG" ]] || fail "$CONFIG introuvable."

read_json_string() {
  local key="$1"
  sed -nE \
    's/^[[:space:]]*"'"$key"'":[[:space:]]*"([^"]*)".*/\1/p' \
    "$CONFIG" | head -n 1
}

REMOTE_DIR="$(read_json_string remoteDir)"
BASE="$(read_json_string base)"

[[ -n "$REMOTE_DIR" ]] || fail "remoteDir absent ou vide."
[[ -n "$BASE" ]] || fail "base absent ou vide."

# Autorise les branches ordinaires pour les tests,
# mais interdit leur déploiement.
if [[ "$BRANCH" != "master" ]] &&
   [[ ! "$BRANCH" =~ ^experience/([a-z0-9]+([_-][a-z0-9]+)*)$ ]]; then

  if [[ "$MODE" == "deploy" ]]; then
    fail "Branche '$BRANCH' interdite au déploiement."
  fi

  echo "INFO : branche non déployable : $BRANCH"
  echo "INFO : les tests peuvent continuer."
   exit 0
fi

# Détermine les chemins attendus selon la branche.
if [[ "$BRANCH" == "master" ]]; then
  EXPECTED_REMOTE="/var/www/labs/lab-front-react/socle"
  EXPECTED_BASE="/"
else
  # Récupère la partie située après le premier "/".
  EXPERIENCE="${BRANCH#*/}"

  # Construit les chemins attendus.
  EXPECTED_REMOTE="/var/www/labs/lab-front-react/experiences/$EXPERIENCE"
  EXPECTED_BASE="/experiences/$EXPERIENCE/"
fi

# Vérifie le dossier distant configuré.
[[ "$REMOTE_DIR" == "$EXPECTED_REMOTE" ]] ||
  fail "remoteDir incorrect. Attendu : $EXPECTED_REMOTE ; obtenu : $REMOTE_DIR"

# Vérifie le chemin de base configuré.
[[ "$BASE" == "$EXPECTED_BASE" ]] ||
  fail "base incorrecte. Attendu : $EXPECTED_BASE ; obtenu : $BASE"

# Affiche le résultat des validations.
echo ""
echo "Branche validée : $BRANCH"
echo "remoteDir validé : $REMOTE_DIR"
echo "base validée : $BASE"

# Expose les valeurs comme sorties GitHub Actions.
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "remote_dir=$REMOTE_DIR"
    echo "base=$BASE"
  } >> "$GITHUB_OUTPUT"
fi
