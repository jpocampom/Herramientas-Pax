#!/usr/bin/env bash
# install.sh — Instala Everything Claude Code (ECC) desde el fork chino
# (xu-xiang/everything-claude-code-zh) o desde el upstream ingles
# (affaan-m/everything-claude-code).
#
#   ./install.sh                          # curado -> ~/.claude  (fuente zh, pineada)
#   ./install.sh --scope repo             # curado -> <repo>/.claude  (persiste en git)
#   ./install.sh --set full               # las 58 skills / 14 agents / 35 commands
#   ./install.sh --source en              # upstream ingles v2.2.0 (286 skills)
#   ./install.sh --stage-hooks            # deja los hooks en ~/.claude/ecc-hooks (NO los activa)
#   ./install.sh --dry-run                # muestra que copiaria
#
# Decisiones deliberadas:
#   - Los hooks NUNCA se activan solos. Son codigo de terceros que corre en cada
#     tool call. Se pueden dejar en disco con --stage-hooks y activarlos a mano.
#   - El set por defecto es curado, no completo. El bundle es 90% ingenieria de
#     software (Go/Django/Swift/SpringBoot/C++); Pax no la usa y cada skill
#     cuesta contexto en toda sesion.
#   - La fuente zh se clona pineada a un commit: el fork esta congelado desde
#     marzo 2026 y no queremos que un cambio silencioso entre sin revisar.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SCOPE="home"      # home | repo
SOURCE="zh"       # zh | en
SET="curated"     # curated | full
STAGE_HOOKS=0
DRY_RUN=0

ZH_URL="https://github.com/xu-xiang/everything-claude-code-zh.git"
ZH_REF="${ECC_ZH_REF:-dfbf9467b90dfd29bffa842c4e0a6977112900e2}"   # v1.7.0, 2026-03-05
EN_URL="https://github.com/affaan-m/everything-claude-code.git"
EN_REF="${ECC_EN_REF:-main}"

# --- Set curado ---------------------------------------------------------------
# Solo lo que (a) aplica a un fondo de PE/M&A o a este repo de herramientas y
# (b) funciona sin scripts ni rutas externas.
CURATED_SKILLS=(
  market-research investor-materials investor-outreach
  article-writing content-engine
  search-first iterative-retrieval verification-loop
  coding-standards
  python-patterns python-testing
)
# Quedan fuera del set curado a proposito (siguen disponibles con --set full):
#   strategic-compact, skill-stocktake  -> dependen de hooks o de rutas ~/.claude/
#   security-scan                       -> requiere AgentShield (herramienta externa)
#   security-review                     -> colisiona con la skill nativa de Claude
#                                          Code, que gana; el archivo queda muerto
CURATED_AGENTS=(
  architect planner code-reviewer security-reviewer python-reviewer
  doc-updater tdd-guide
)
CURATED_COMMANDS=(
  plan code-review verify checkpoint learn
  skill-create test-coverage update-docs orchestrate
)

# --- Argumentos ---------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)  SCOPE="${2:?--scope requiere home|repo}"; shift 2 ;;
    --source) SOURCE="${2:?--source requiere zh|en}"; shift 2 ;;
    --set)    SET="${2:?--set requiere curated|full}"; shift 2 ;;
    --stage-hooks) STAGE_HOOKS=1; shift ;;
    --dry-run)     DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "ERROR: argumento desconocido '$1'" >&2; exit 1 ;;
  esac
done

case "$SCOPE"  in home|repo) ;; *) echo "ERROR: --scope debe ser home o repo" >&2; exit 1 ;; esac
case "$SOURCE" in zh|en)     ;; *) echo "ERROR: --source debe ser zh o en" >&2; exit 1 ;; esac
case "$SET"    in curated|full) ;; *) echo "ERROR: --set debe ser curated o full" >&2; exit 1 ;; esac

if [[ "$SCOPE" == "repo" && "$SET" == "full" ]]; then
  echo "AVISO: --scope repo --set full mete 58 skills en el indice de contexto de"
  echo "       toda sesion de este repo. Recomendado: --set curated." >&2
fi

command -v git >/dev/null || { echo "ERROR: git no esta en el PATH" >&2; exit 1; }

if [[ "$SCOPE" == "home" ]]; then
  DEST="${ECC_DEST:-$HOME/.claude}"
else
  DEST="${ECC_DEST:-$REPO_ROOT/.claude}"
fi

if [[ "$SOURCE" == "zh" ]]; then URL="$ZH_URL"; REF="$ZH_REF"; else URL="$EN_URL"; REF="$EN_REF"; fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
SRC="$WORKDIR/ecc"

echo "==> Fuente:  $URL @ $REF"
echo "==> Destino: $DEST  (scope=$SCOPE, set=$SET)"

# El zip de /archive/ redirige a codeload.github.com y muchos proxies corporativos
# lo bloquean con 403; git clone pasa en mas entornos.
if [[ "$REF" == "main" ]]; then
  git clone --quiet --depth 1 --filter=blob:none --sparse "$URL" "$SRC"
else
  git clone --quiet --filter=blob:none --sparse "$URL" "$SRC"
  git -C "$SRC" checkout --quiet "$REF"
fi
git -C "$SRC" sparse-checkout set skills agents commands rules hooks scripts contexts mcp-configs >/dev/null

echo "==> Commit clonado: $(git -C "$SRC" rev-parse --short HEAD)"

copy() { # copy <origen> <destino>
  local from="$1" to="$2"
  if [[ ! -e "$from" ]]; then echo "    falta (skip): ${from#$SRC/}" >&2; return 0; fi
  if (( DRY_RUN )); then echo "    [dry-run] ${from#$SRC/} -> ${to#$DEST/}"; return 0; fi
  mkdir -p "$(dirname "$to")"
  rm -rf "$to"
  cp -R "$from" "$to"
}

install_group() { # install_group <dir> <items...>
  local dir="$1"; shift
  echo "--> $dir/"
  if [[ "$SET" == "full" ]]; then
    local item
    for item in "$SRC/$dir"/*; do
      [[ -e "$item" ]] || continue
      [[ "$(basename "$item")" == "README.md" ]] && continue
      copy "$item" "$DEST/$dir/$(basename "$item")"
    done
  else
    local name
    for name in "$@"; do
      if [[ -d "$SRC/$dir/$name" ]]; then copy "$SRC/$dir/$name" "$DEST/$dir/$name"
      else copy "$SRC/$dir/$name.md" "$DEST/$dir/$name.md"; fi
    done
  fi
}

install_group skills   "${CURATED_SKILLS[@]}"
install_group agents   "${CURATED_AGENTS[@]}"
install_group commands "${CURATED_COMMANDS[@]}"

# Las rules solo las lee Claude Code desde ~/.claude/rules (o si un CLAUDE.md las
# referencia). En scope repo no se instalan para no crear referencias muertas.
if [[ "$SCOPE" == "home" ]]; then
  echo "--> rules/"
  copy "$SRC/rules" "$DEST/rules"
fi

if (( STAGE_HOOKS )); then
  echo "--> hooks staging (INACTIVOS) -> $DEST/ecc-hooks/"
  copy "$SRC/hooks/hooks.json" "$DEST/ecc-hooks/hooks.json"
  copy "$SRC/scripts"          "$DEST/ecc-hooks/scripts"
fi

if (( DRY_RUN )); then echo; echo "Dry-run: no se escribio nada."; exit 0; fi

cat <<MSG

Listo.
  skills:   $(ls -1 "$DEST/skills"   2>/dev/null | wc -l | tr -d ' ')
  agents:   $(ls -1 "$DEST/agents"   2>/dev/null | wc -l | tr -d ' ')
  commands: $(ls -1 "$DEST/commands" 2>/dev/null | wc -l | tr -d ' ')

Las skills y los agents se cargan solos. Los commands se invocan con /<nombre>.
Reinicia Claude Code para que tome los cambios.
MSG

if (( STAGE_HOOKS )); then
  cat <<'MSG'

Hooks: quedaron en disco pero DESACTIVADOS. Para activarlos hay que copiar a mano
los bloques de ecc-hooks/hooks.json dentro de ~/.claude/settings.json y cambiar
${CLAUDE_PLUGIN_ROOT} por la ruta de ecc-hooks/. Leelos antes: corren en cada
tool call, bloquean `npm run dev` fuera de tmux, y observe.sh escribe en disco
en cada llamada.
MSG
fi
