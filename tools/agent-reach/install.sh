#!/usr/bin/env bash
# Instala Agent Reach (https://github.com/Panniantong/agent-reach) en un venv aislado.
# Probado para macOS (Apple Silicon e Intel) y Linux.
#
# Modo seguro por defecto: instala el paquete y corre SOLO la verificacion de
# dependencias (read-only). No toca el sistema, no instala gh/mcporter, no pide
# cookies. Para permitir cambios de sistema hay que pasar --system de forma
# explicita, tal como exige la guia upstream.
#
#   ./install.sh              # instalar + chequeo read-only
#   ./install.sh --dry-run    # muestra que haria --system, sin hacerlo
#   ./install.sh --system     # ademas permite instalar dependencias de sistema
#
# Despues correr ./verify.sh para confirmar que los canales alcanzan la red.
#
set -euo pipefail

VENV="${AGENT_REACH_VENV:-$HOME/.agent-reach-venv}"
BINDIR="${AGENT_REACH_BINDIR:-$HOME/.local/bin}"
# Set de canales aprobado: solo plataformas occidentales. Excluye a proposito
# bilibili, xiaohongshu, xiaoyuzhou, xueqiu y v2ex.
CHANNELS="${AGENT_REACH_CHANNELS:-twitter,reddit,linkedin}"
SRC_REF="${AGENT_REACH_REF:-main}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

die() { echo "ERROR: $*" >&2; exit 1; }

# --- Requisitos -------------------------------------------------------------
# En macOS 'git' y 'python3' pueden ser stubs de Xcode que abren un dialogo de
# instalacion en vez de correr. Se detecta antes de hacer nada.
command -v git >/dev/null || die "no encuentro git. En macOS: xcode-select --install"
git --version >/dev/null 2>&1 || die "git no ejecuta. En macOS: xcode-select --install"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null || die "no encuentro $PY en el PATH"
"$PY" --version >/dev/null 2>&1 || die "$PY no ejecuta (stub de Xcode?). En macOS: brew install python@3.12"

"$PY" - <<'EOF' || die "agent-reach requiere Python >= 3.10"
import sys
sys.exit(0 if sys.version_info >= (3, 10) else 1)
EOF

"$PY" -c 'import venv' >/dev/null 2>&1 \
  || die "este Python no trae el modulo venv. En Debian/Ubuntu: apt install python3-venv"

echo "==> Python: $("$PY" --version) ($(command -v "$PY"))"

# --- Instalacion ------------------------------------------------------------
echo "==> Creando venv en $VENV"
[ -d "$VENV" ] && echo "    (ya existia; se reutiliza)"
"$PY" -m venv "$VENV"
"$VENV/bin/pip" install --quiet --upgrade pip

# El zip de /archive/ puede estar bloqueado por politicas de egress corporativas
# (devuelve 403 al redirigir a codeload.github.com); clonar por git funciona en
# mas entornos y da exactamente el mismo contenido.
echo "==> Clonando agent-reach ($SRC_REF)"
git clone --quiet --depth 1 --branch "$SRC_REF" \
  https://github.com/Panniantong/agent-reach.git "$WORKDIR/agent-reach"
COMMIT="$(git -C "$WORKDIR/agent-reach" rev-parse HEAD)"
echo "    commit $COMMIT"

echo "==> Instalando agent-reach"
"$VENV/bin/pip" install --quiet "$WORKDIR/agent-reach"

# yt-dlp entra como dependencia del paquete; agent-reach lo busca en el PATH.
mkdir -p "$BINDIR"
ln -sf "$VENV/bin/agent-reach" "$BINDIR/agent-reach"
[ -x "$VENV/bin/yt-dlp" ] && ln -sf "$VENV/bin/yt-dlp" "$BINDIR/yt-dlp"

# yt-dlp necesita un runtime JS para los formatos nuevos de YouTube.
if command -v node >/dev/null 2>&1; then
  mkdir -p "$HOME/.config/yt-dlp"
  grep -qxF -- '--js-runtimes node' "$HOME/.config/yt-dlp/config" 2>/dev/null \
    || printf '%s\n' '--js-runtimes node' >> "$HOME/.config/yt-dlp/config"
else
  echo "    aviso: node no esta instalado; YouTube quedara parcial (brew install node)"
fi

echo "==> Verificacion de dependencias (read-only salvo que pases --system)"
"$VENV/bin/agent-reach" install --env=auto "$@"

# --- Cierre -----------------------------------------------------------------
echo
echo "Listo. agent-reach $("$VENV/bin/agent-reach" --version 2>/dev/null | tail -1)"
echo "Binario: $BINDIR/agent-reach"

case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *)
    case "${SHELL##*/}" in
      zsh)  RC="$HOME/.zshrc" ;;
      bash) RC="$HOME/.bash_profile" ;;
      *)    RC="tu archivo de perfil" ;;
    esac
    echo
    echo "AVISO: $BINDIR no esta en tu PATH. Agregalo:"
    echo "  echo 'export PATH=\"$BINDIR:\$PATH\"' >> $RC && exec \$SHELL"
    ;;
esac

cat <<MSG

Siguiente paso:  ./verify.sh        (comprueba que los canales alcanzan la red)
Estado:          agent-reach doctor

Canales aprobados para Pax (sin plataformas chinas):
  agent-reach install --env=auto --system --channels=$CHANNELS

NO usar --channels=all: incluye Bilibili, Xiaohongshu, Xiaoyuzhou, Xueqiu y
V2EX, que no aportan al flujo de deals y agregan binarios de terceros. Esos
canales aparecen igual en 'doctor' como no instalados: el paquete tiene la
lista fija (agent_reach/channels/__init__.py, ALL_CHANNELS) y no expone un
flag para ocultarlos. Mientras no se instalen, quedan inertes.

Los canales que piden cookies (Twitter, Reddit, Facebook, Instagram) requieren
sesion de navegador. Usar cuenta secundaria, nunca la cuenta corporativa: la
cookie da acceso total y las plataformas banean por trafico no-navegador.
MSG
