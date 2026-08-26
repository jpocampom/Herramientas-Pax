#!/usr/bin/env bash
# Verifica que Agent Reach quedo instalado Y que de verdad alcanza la red.
#
# Distingue las dos fallas que 'agent-reach doctor' confunde:
#   - el paquete no esta bien instalado
#   - el paquete esta bien pero la red bloquea el host
#
# 'doctor' reporta Web y RSS como OK sin hacer una peticion real: son falsos
# positivos. Este script si pega a la red.
#
#   ./verify.sh
#
set -uo pipefail

VENV="${AGENT_REACH_VENV:-$HOME/.agent-reach-venv}"
AR="$VENV/bin/agent-reach"
FAIL=0

hr() { printf '%s\n' "------------------------------------------------------------"; }

# --- 1. Instalacion ---------------------------------------------------------
echo "1) Instalacion"
hr
if [ ! -x "$AR" ]; then
  echo "   [X] no encuentro $AR — corre ./install.sh primero"
  exit 1
fi
echo "   [ok] $("$AR" --version 2>&1 | tail -1)"
echo "   [ok] venv: $VENV"

# El paquete se importa y registra sus canales?
"$VENV/bin/python" - <<'EOF' || FAIL=1
from agent_reach.channels import ALL_CHANNELS
print(f"   [ok] paquete importable, {len(ALL_CHANNELS)} canales registrados")
EOF

# --- 2. Alcance de red por canal -------------------------------------------
echo
echo "2) Alcance de red (canales aprobados)"
hr
echo "   Un codigo HTTP cualquiera significa que la conexion llego."
echo "   '000' significa bloqueado por firewall/proxy: ahi esta el problema."
echo

probe() { # nombre, url
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 -A 'Mozilla/5.0' "$2" 2>/dev/null)
  if [ "$code" = "000" ]; then
    printf '   [X]  %-14s BLOQUEADO   %s\n' "$1" "$2"
    FAIL=1
  else
    printf '   [ok] %-14s HTTP %-6s %s\n' "$1" "$code" "$2"
  fi
}

probe "Web/Jina"  "https://r.jina.ai/https://example.com"
probe "Exa Search" "https://mcp.exa.ai/mcp"
probe "YouTube"   "https://www.youtube.com"
probe "Twitter/X" "https://x.com"
probe "Reddit"    "https://www.reddit.com"
probe "LinkedIn"  "https://www.linkedin.com"
probe "GitHub"    "https://api.github.com"

# --- 3. Prueba funcional real ----------------------------------------------
echo
echo "3) Prueba funcional (lectura real, no solo conectividad)"
hr
"$VENV/bin/python" - <<'EOF' || FAIL=1
import sys
import feedparser

FEED = "https://feeds.bbci.co.uk/news/business/rss.xml"
d = feedparser.parse(FEED)
if d.entries:
    print(f"   [ok] RSS: {len(d.entries)} entradas leidas de {FEED}")
    print(f"        ejemplo: {d.entries[0].title[:60]}")
else:
    print(f"   [X]  RSS: 0 entradas. Causa: {d.get('bozo_exception', 'desconocida')}")
    sys.exit(1)
EOF

if command -v yt-dlp >/dev/null 2>&1 || [ -x "$VENV/bin/yt-dlp" ]; then
  YTDLP="$(command -v yt-dlp || echo "$VENV/bin/yt-dlp")"
  if "$YTDLP" --simulate --quiet --no-warnings \
       "https://www.youtube.com/watch?v=dQw4w9WgXcQ" >/dev/null 2>&1; then
    echo "   [ok] YouTube: yt-dlp resuelve metadatos de un video"
  else
    echo "   [!]  YouTube: yt-dlp no pudo resolver el video (red, o falta node)"
  fi
fi

# --- 4. Doctor --------------------------------------------------------------
echo
echo "4) agent-reach doctor (referencia; ver aviso de falsos positivos arriba)"
hr
"$AR" doctor 2>&1 | sed 's/^/   /'

# --- Veredicto --------------------------------------------------------------
echo
hr
if [ "$FAIL" -eq 0 ]; then
  echo "VEREDICTO: instalacion correcta y con salida a internet."
  echo "Siguiente: configurar credenciales de los canales que las pidan."
else
  echo "VEREDICTO: hay fallas arriba marcadas con [X]."
  echo "Si son todas '000', el paquete esta bien y el problema es la red"
  echo "(firewall corporativo, VPN o proxy). No reinstales: revisa la red."
fi
exit "$FAIL"
