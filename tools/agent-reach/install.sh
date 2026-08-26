#!/usr/bin/env bash
# Instala Agent Reach (https://github.com/Panniantong/agent-reach) en un venv aislado.
#
# Modo seguro por defecto: instala el paquete y corre SOLO la verificacion de
# dependencias (read-only). No toca el sistema, no instala gh/mcporter, no pide
# cookies. Para permitir cambios de sistema hay que pasar --system de forma
# explicita, tal como exige la guia upstream.
#
#   ./install.sh              # instalar + chequeo read-only
#   ./install.sh --system     # ademas permite instalar dependencias de sistema
#   ./install.sh --dry-run    # muestra que haria --system, sin hacerlo
#
set -euo pipefail

VENV="${AGENT_REACH_VENV:-$HOME/.agent-reach-venv}"
SRC_REF="${AGENT_REACH_REF:-main}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null || { echo "ERROR: no encuentro $PY en el PATH" >&2; exit 1; }

echo "==> Creando venv en $VENV"
"$PY" -m venv "$VENV"
"$VENV/bin/pip" install --quiet --upgrade pip

# El zip de /archive/ puede estar bloqueado por politicas de egress corporativas;
# clonar por git funciona en mas entornos y da el mismo contenido.
echo "==> Clonando agent-reach ($SRC_REF)"
git clone --depth 1 --branch "$SRC_REF" \
  https://github.com/Panniantong/agent-reach.git "$WORKDIR/agent-reach"

echo "==> Instalando agent-reach"
"$VENV/bin/pip" install --quiet "$WORKDIR/agent-reach"

# yt-dlp entra como dependencia; agent-reach lo busca en el PATH.
BINDIR="${AGENT_REACH_BINDIR:-$HOME/.local/bin}"
mkdir -p "$BINDIR"
ln -sf "$VENV/bin/agent-reach" "$BINDIR/agent-reach"
[ -x "$VENV/bin/yt-dlp" ] && ln -sf "$VENV/bin/yt-dlp" "$BINDIR/yt-dlp"

# yt-dlp necesita un runtime JS para los formatos nuevos de YouTube.
if command -v node >/dev/null; then
  mkdir -p "$HOME/.config/yt-dlp"
  grep -qxF -- '--js-runtimes node' "$HOME/.config/yt-dlp/config" 2>/dev/null \
    || printf '%s\n' '--js-runtimes node' >> "$HOME/.config/yt-dlp/config"
fi

echo "==> Verificacion"
"$VENV/bin/agent-reach" install --env=auto "$@"

cat <<MSG

Listo. Binario: $BINDIR/agent-reach  (agrega $BINDIR al PATH si hace falta)
Estado de canales:  agent-reach doctor
Canales opcionales: agent-reach install --env=auto --system --channels=<lista>

Los canales que piden cookies (Twitter, Reddit, XHS, Facebook, Instagram,
Xueqiu) requieren sesion de navegador. Usar cuenta secundaria, nunca la
cuenta corporativa: la cookie da acceso total y las plataformas banean por
trafico no-navegador.
MSG
