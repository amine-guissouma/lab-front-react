#!/usr/bin/env bash

# Active un mode strict :
# -e : arrête le script en cas d'erreur non gérée.
# -u : signale l'utilisation de variables non définies.
# pipefail : détecte les erreurs dans les pipelines de commandes.
set -euo pipefail

# ============================================================
# 1. INITIALISATION DES TESTS
# ============================================================

# Détermine le chemin absolu de la racine du projet.
# BASH_SOURCE[0] correspond au fichier de test actuel.
# Le dossier ".." permet de remonter à la racine du projet.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Définit le chemin du script que l'on souhaite tester.
SCRIPT_UNDER_TEST="$PROJECT_ROOT/scripts/validate-deployment.sh"

# Vérifie que le script à tester existe.
# Si le fichier est absent, les tests ne peuvent pas continuer.
if [[ ! -f "$SCRIPT_UNDER_TEST" ]]; then
  echo "ERREUR : script introuvable : $SCRIPT_UNDER_TEST" >&2
  exit 1
fi

# ============================================================
# 2. PRÉPARATION DE L'ENVIRONNEMENT DE TEST
# ============================================================

# Crée un répertoire temporaire pour stocker les fichiers de test.
# Les fichiers temporaires ne modifieront pas le projet réel.
TMP_ROOT="$(mktemp -d)"

# Supprime automatiquement le répertoire temporaire à la fin
# du script, même si les tests échouent.
trap 'rm -rf "$TMP_ROOT"' EXIT

# Compteurs du nombre de vérifications réussies et échouées.
PASS=0
FAIL=0

# CASE_DIR contiendra le répertoire temporaire du test courant.
CASE_DIR=""

# ACTUAL_STATUS contiendra le code de retour du script testé.
# 0 signifie que le script a réussi ; une valeur différente
# de 0 indique généralement une erreur.
ACTUAL_STATUS=0

# ============================================================
# 3. CRÉATION D'UN CAS DE TEST
# ============================================================

# Crée un répertoire indépendant pour un nouveau test.
# Le fichier github_output simule le fichier utilisé par
# GitHub Actions pour récupérer les valeurs de sortie du script.
new_case() {
  CASE_DIR="$(mktemp -d "$TMP_ROOT/case.XXXXXX")"
  : > "$CASE_DIR/github_output"
}

# ============================================================
# 4. CRÉATION DU FICHIER deployment.json DE TEST
# ============================================================

# Génère un deployment.json temporaire avec les valeurs fournies.
# Cela permet de tester plusieurs configurations sans modifier
# le véritable fichier deployment.json du projet.
write_config() {
  local remote_dir="$1"
  local base="$2"

  cat > "$CASE_DIR/deployment.json" <<EOF
{
  "remoteDir": "$remote_dir",
  "base": "$base"
}
EOF
}

# ============================================================
# 5. EXÉCUTION DU SCRIPT À TESTER
# ============================================================

# Exécute validate-deployment.sh avec une branche et un mode donnés.
# Le script est lancé depuis le répertoire temporaire afin
# qu'il utilise le deployment.json du test.
#
# GITHUB_REF_NAME simule le nom de la branche dans GitHub Actions.
# GITHUB_HEAD_REF est supprimée pour éviter qu'elle ne remplace
# la branche simulée.
# GITHUB_OUTPUT simule le fichier de sortie de GitHub Actions.
#
# Les messages du script testé sont enregistrés dans un fichier log.
run_script() {
  local branch="$1"
  local mode="$2"

  if (
    cd "$CASE_DIR"
    unset GITHUB_HEAD_REF
    export GITHUB_REF_NAME="$branch"
    export GITHUB_OUTPUT="$CASE_DIR/github_output"

    bash "$SCRIPT_UNDER_TEST" "$mode"
  ) > "$CASE_DIR/log" 2>&1; then
    ACTUAL_STATUS=0
  else
    ACTUAL_STATUS=$?
  fi
}

# ============================================================
# 6. VÉRIFICATION DU CODE DE RETOUR
# ============================================================

# Compare le code de retour réel avec celui attendu.
#
# expected_status = 0 : le script doit réussir.
# expected_status = 1 : le script doit refuser la configuration.
#
# Le test est comptabilisé comme réussi ou échoué.
# En cas d'échec, les messages du script testé sont affichés.
assert_exit() {
  local name="$1"
  local expected_status="$2"

  if [[ "$ACTUAL_STATUS" -eq "$expected_status" ]]; then
    echo "OK   : $name"
    PASS=$((PASS + 1))
  else
    echo "ECHEC : $name"
    echo "  Code attendu : $expected_status"
    echo "  Code obtenu  : $ACTUAL_STATUS"
    cat "$CASE_DIR/log"
    FAIL=$((FAIL + 1))
  fi
}

# ============================================================
# 7. VÉRIFICATION DES SORTIES GITHUB ACTIONS
# ============================================================

# Vérifie qu'une ligne précise est présente dans github_output.
# grep -F recherche le texte littéralement.
# grep -x exige que la ligne entière corresponde.
# grep -q masque la sortie de grep.
#
# Cette fonction vérifie notamment que le script fournit
# remote_dir et base aux étapes suivantes du workflow CI/CD.
assert_output() {
  local name="$1"
  local expected_line="$2"

  if grep -Fxq "$expected_line" "$CASE_DIR/github_output"; then
    echo "OK   : $name"
    PASS=$((PASS + 1))
  else
    echo "ECHEC : $name"
    echo "  Ligne attendue : $expected_line"
    echo "  Contenu obtenu :"
    cat "$CASE_DIR/github_output"
    FAIL=$((FAIL + 1))
  fi
}

# ============================================================
# 8. EXÉCUTION DES TESTS
# ============================================================

echo "=== Tests de validate-deployment.sh ==="
echo

# TEST 1 : branche master avec une configuration valide.
# Vérifie que le socle peut être déployé à la racine du site
# et que les sorties remote_dir et base sont correctement produites.
new_case
write_config \
  "/var/www/labs/lab-front-react/socle" \
  "/"

run_script "master" "deploy"
assert_exit "master : configuration valide" 0
assert_output "master : remote_dir exporte" \
  "remote_dir=/var/www/labs/lab-front-react/socle"
assert_output "master : base exportee" "base=/"

# TEST 2 : branche experience/token avec une configuration valide.
# Vérifie que l'expérience token utilise son propre répertoire
# et le préfixe URL /experiences/token/.
new_case
write_config \
  "/var/www/labs/lab-front-react/experiences/token" \
  "/experiences/token/"

run_script "experience/token" "deploy"
assert_exit "experience/token : configuration valide" 0
assert_output "token : remote_dir exporte" \
  "remote_dir=/var/www/labs/lab-front-react/experiences/token"
assert_output "token : base exportee" \
  "base=/experiences/token/"

# TEST 3 : mauvaise destination distante.
# La branche token ne doit pas pouvoir déployer dans le répertoire
# du socle. Le script doit donc renvoyer un code d'erreur.
new_case
write_config \
  "/var/www/labs/lab-front-react/socle" \
  "/experiences/token/"

run_script "experience/token" "deploy"
assert_exit "token : mauvais remoteDir refuse" 1

# TEST 4 : mauvaise base Vite.
# Vérifie que le script refuse la racine "/" pour l'expérience token.
new_case
write_config \
  "/var/www/labs/lab-front-react/experiences/token" \
  "/"

run_script "experience/token" "deploy"
assert_exit "token : mauvaise base refusee" 1

# TEST 5 : nom de branche invalide.
# La convention autorise uniquement les noms minuscules,
# chiffres et tirets selon le format défini dans le script.
# La majuscule dans "Token" doit donc entraîner un refus.
new_case
write_config \
  "/var/www/labs/lab-front-react/experiences/token" \
  "/experiences/token/"

run_script "experience/Token" "deploy"
assert_exit "nom de branche avec majuscule refuse" 1

# TEST 6 : branche feature en mode deploy.
# Une branche de développement ordinaire ne doit jamais
# être autorisée à déployer sur le serveur.
new_case
write_config \
  "/var/www/labs/lab-front-react/socle" \
  "/"

run_script "feature/ma-fonction" "deploy"
assert_exit "branche feature refusee en deploy" 1

# TEST 7 : branche feature en mode check.
# En mode check, une branche de développement ordinaire
# peut poursuivre les contrôles sans être déployable.
new_case
write_config \
  "/var/www/labs/lab-front-react/socle" \
  "/"

run_script "feature/ma-fonction" "check"
assert_exit "branche feature autorisee en check" 0

# TEST 8 : fichier deployment.json absent.
# Vérifie que le script s'arrête lorsqu'il ne peut pas
# lire la configuration nécessaire au déploiement.
new_case

run_script "master" "deploy"
assert_exit "deployment.json absent : erreur" 1

# TEST 9 : remoteDir vide.
# Vérifie que le script refuse une destination distante vide.
new_case
write_config "" "/"

run_script "master" "deploy"
assert_exit "remoteDir vide : erreur" 1

# TEST 10 : base vide.
# Vérifie que le script refuse une base Vite vide.
new_case
write_config "/var/www/labs/lab-front-react/socle" ""

run_script "master" "deploy"
assert_exit "base vide : erreur" 1

# TEST 11 : mode inconnu.
# Le script doit accepter uniquement les modes check et deploy.
new_case
write_config "/var/www/labs/lab-front-react/socle" "/"

run_script "master" "invalid"
assert_exit "mode inconnu : erreur" 1

# ============================================================
# 9. BILAN DES TESTS
# ============================================================

# Affiche le nombre de vérifications réussies et échouées.
echo
echo "=== Résultat ==="
echo "Réussis : $PASS"
echo "Échoués  : $FAIL"

# Retourne un code d'erreur si au moins un test a échoué.
# GitHub Actions pourra alors marquer l'étape comme échouée.
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

# Tous les tests ont réussi.
echo "Tous les tests sont réussis."
