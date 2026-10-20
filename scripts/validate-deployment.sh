
#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "ERREUR : $*" >&2
  exit 1
}

MODE="${1:-check}"

case "$MODE" in
  check|deploy) ;;
  *) fail "Mode inconnu : $MODE (check ou deploy attendu)." ;;
esac

BRANCH="${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-$(git branch --show-current)}}"

[[ -n "$BRANCH" ]] || fail "Impossible de déterminer la branche."

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

# Les branches ordinaires peuvent être testées,
# mais elles ne sont pas autorisées à déployer.
if [[ "$BRANCH" != "master" ]] &&
   [[ ! "$BRANCH" =~ ^experience/([a-z0-9]+(-[a-z0-9]+)*)$ ]]; then
  if [[ "$MODE" == "deploy" ]]; then
    fail "Branche '$BRANCH' interdite au déploiement."
  fi

  echo "INFO : branche non déployable : $BRANCH"
  echo "INFO : les tests peuvent continuer."
  exit 0
fi

if [[ "$BRANCH" == "master" ]]; then
  EXPECTED_REMOTE="/var/www/labs/lab-front-react/socle"
  EXPECTED_BASE="/"
else
  [[ "$BRANCH" =~ ^experience/([a-z0-9]+(-[a-z0-9]+)*)$ ]] ||
    fail "Nom de branche invalide : $BRANCH"

  EXPERIENCE="${BASH_REMATCH[1]}"
  EXPECTED_REMOTE="/var/www/labs/lab-front-react/experiences/$EXPERIENCE"
  EXPECTED_BASE="/experiences/$EXPERIENCE/"
fi

[[ "$REMOTE_DIR" == "$EXPECTED_REMOTE" ]] ||
  fail "remoteDir incorrect. Attendu : $EXPECTED_REMOTE ; obtenu : $REMOTE_DIR"

[[ "$BASE" == "$EXPECTED_BASE" ]] ||
  fail "base incorrecte. Attendu : $EXPECTED_BASE ; obtenu : $BASE"

echo "Branche validée : $BRANCH"
echo "remoteDir validé : $REMOTE_DIR"
echo "base validée : $BASE"

# Sorties utilisables par GitHub Actions.
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "remoteDir=$REMOTE_DIR"
    echo "base=$BASE"
  } >> "$GITHUB_OUTPUT"
fi
