# Agent Reach

Instalador y notas de operación para [Agent Reach](https://github.com/Panniantong/agent-reach)
v1.5.0 — un selector/instalador/router que le da a un agente acceso de lectura a
plataformas externas (web, YouTube, GitHub, RSS, Exa, Twitter/X, Reddit, XHS,
Bilibili, Xueqiu, LinkedIn, Facebook, Instagram). No es un wrapper: instala las
CLIs upstream y el agente las llama directo.

## Instalación en la laptop (macOS)

Requisitos: Python >= 3.10 y git. Si `python3 --version` abre un diálogo de
Xcode, corre `xcode-select --install` o instala `brew install python@3.12`.
Para YouTube completo hace falta `brew install node`.

```bash
git clone https://github.com/jpocampom/Herramientas-Pax.git
cd Herramientas-Pax/tools/agent-reach

./install.sh              # instala + chequeo read-only (no toca el sistema)
./verify.sh               # comprueba que los canales SÍ alcanzan la red
```

`verify.sh` es el paso que importa. `agent-reach doctor` reporta Web, RSS y
YouTube como ✅ sin hacer una petición real — son falsos positivos.
`verify.sh` sí pega a la red y distingue las dos fallas que doctor confunde:
paquete mal instalado vs. host bloqueado. En un `[X] BLOQUEADO` con `000` el
problema es la red (VPN, firewall corporativo, proxy), no la instalación:
reinstalar no arregla nada.

Si todo sale `[ok]`, recién ahí conviene sumar canales con credenciales:

```bash
./install.sh --dry-run    # preview de lo que haría --system
./install.sh --system     # permite instalar dependencias de sistema
agent-reach install --env=auto --system --channels=twitter,reddit,linkedin
```

Queda en `~/.agent-reach-venv`, con symlink en `~/.local/bin/agent-reach`
(en macOS ese directorio no está en el `PATH` por defecto; el instalador te
dice la línea exacta a agregar en `~/.zshrc`). Config y tokens en
`~/.agent-reach/`. Nada se escribe dentro de este repo.

### Desinstalar

```bash
rm -rf ~/.agent-reach-venv ~/.agent-reach ~/.local/bin/agent-reach ~/.local/bin/yt-dlp
```

## Estado verificado en el contenedor remoto de Claude Code (2026-08-26)

Instalación: correcta. Funcionalidad: **0 de 15 canales operativos.**

El proxy de egress de la organización responde `403` al `CONNECT` de todo host
que no esté en la allowlist (`github.com`, `pypi.org`, `registry.npmjs.org`,
`api.anthropic.com` y poco más). Bloqueados y verificados uno por uno:
`r.jina.ai`, `x.com`, `reddit.com`, `youtube.com`, `api.bilibili.com`,
`v2ex.com`, `xueqiu.com`, `mcp.exa.ai`, y los hosts de feeds RSS.

`agent-reach doctor` reporta "2/15" porque los checks de Web y RSS no hacen una
petición real — son falsos positivos. El número real es 0.

Notas adicionales del entorno:

- `pip install https://github.com/.../archive/main.zip` (el método de la guía
  upstream) falla con 403 porque redirige a `codeload.github.com`. El script usa
  `git clone`, que sí pasa.
- El contenedor es efímero: lo instalado se pierde al reciclarse la sesión. Por
  eso el instalador vive en el repo y no en el contenedor.

Conclusión: Agent Reach sirve en una máquina con salida a internet abierta
(laptop, VPS propio), no dentro de este sandbox salvo que se amplíe la política
de egress del entorno.

## Verificación de integridad (2026-08-26)

Se comparó el zip `Agent-Reach-main` provisto contra la fuente clonada e
instalada. Resultado: **idénticos, archivo por archivo.**

| Comprobación | Resultado |
|---|---|
| Commit del clone instalado | `06c202b03400a7d31886bf4399213706da1a0324` (2026-08-25) |
| Commit declarado en el zip | `06c202b03400a7d31886bf4399213706da1a0324` |
| `diff -rq` zip vs. fuente clonada | sin diferencias |
| `diff -rq` zip vs. `site-packages/agent_reach` | sin diferencias |
| Versión | 1.5.0 en ambos |

Es decir: el zip no aporta nada nuevo ni corrige el problema de red. La
instalación está bien hecha; lo que no funciona es la salida a internet.

## Qué hace falta para que funcione en el entorno remoto

La política de egress se define **en el entorno**, no dentro de la sesión: no
se puede cambiar desde el contenedor. Esta sesión corre en el entorno
`Review skills` (`env_01Udf8siXVm71fbBhmn5Qa2k`). Hay que editar su política
de red en claude.ai/code (o crear un entorno propio para este repo) y abrir
una sesión nueva; el contenedor actual no toma el cambio.

Permitido hoy: `github.com`, `pypi.org`, `files.pythonhosted.org`,
`registry.npmjs.org`, `api.anthropic.com`. Nada más.
(`api.github.com` responde pero está limitado a los repos de la sesión, así
que ni siquiera `gh` serviría para búsquedas generales.)

Allowlist mínima para el set de canales aprobado:

| Canal | Hosts |
|---|---|
| Web (Jina Reader) | `r.jina.ai` |
| Exa Search | `mcp.exa.ai` |
| YouTube | `youtube.com`, `googlevideo.com`, `ytimg.com` |
| Twitter/X | `x.com`, `api.x.com`, `twitter.com` |
| Reddit | `reddit.com`, `oauth.reddit.com` |
| LinkedIn | `linkedin.com` |
| RSS | los dominios de cada feed |

Prueba que aísla la falla: contra un host permitido (`pypi.org/rss/updates.xml`)
el canal RSS parsea 100 entradas sin error. El paquete funciona; lo que falla
es exclusivamente la salida de red.

## Canales: set aprobado

Excluidas a propósito las plataformas de consumo chino: **Bilibili,
Xiaohongshu, Xiaoyuzhou, V2EX y Xueqiu.** Ninguna está instalada — son canales
opcionales que solo entran con `--system --channels=...`, y ese comando nunca
se corrió.

| Canal | Estado |
|---|---|
| Web (Jina), GitHub, RSS, Exa, YouTube | núcleo, sin credenciales |
| Twitter/X, Reddit, LinkedIn | opcionales aprobados, requieren login |
| Facebook, Instagram | opcionales, solo si hay Chrome con OpenCLI |
| Bilibili, Xiaohongshu, Xiaoyuzhou, V2EX, Xueqiu | **excluidos** |

```bash
# Correcto:
agent-reach install --env=auto --system --channels=twitter,reddit,linkedin
# Nunca:
agent-reach install --env=auto --system --channels=all   # arrastra los 5 chinos
```

Limitación: `ALL_CHANNELS` en `agent_reach/channels/__init__.py` es una lista
fija y el paquete no expone un flag para ocultar canales. Los cinco excluidos
van a seguir apareciendo en `agent-reach doctor` marcados como no instalados.
Mientras no se instalen quedan inertes: no ejecutan red ni guardan credenciales.

Nota: Xueqiu es el único del grupo que no es entretenimiento — es la comunidad
bursátil china (cotizaciones + foros). Si alguna vez se miran comparables
listados en Shanghái o Shenzhen, sería el único de los cinco que valdría
reconsiderar.

## Riesgos antes de configurar canales

- **Cookies = acceso total a la cuenta.** Twitter, Reddit, Facebook e
  Instagram se autentican con la cookie de sesión del navegador,
  guardada en claro en `~/.agent-reach/`. Usar cuenta secundaria; nunca la
  cuenta corporativa ni un LinkedIn con red de contrapartes.
- **Riesgo de baneo.** Las plataformas detectan tráfico no-navegador y
  restringen o cierran la cuenta. La propia guía upstream lo advierte.
- **Código de terceros.** Repo de un solo autor, sin publicación en PyPI, la
  instalación es un zip/clone de `main` (no un tag firmado). El contenido de
  `main` puede cambiar entre una instalación y otra. Fijar un commit vía
  `AGENT_REACH_REF` si se quiere reproducibilidad.
- **`--system` y `--channels=all`** instalan binarios de terceros adicionales
  (OpenCLI, rdt-cli, bili-cli, xiaohongshu-mcp) desde GitHub. Cada uno amplía la
  superficie. Aprobar canal por canal, no en bloque; ver el set aprobado arriba.

## Comandos útiles

| Comando | Qué hace |
|---|---|
| `agent-reach doctor` | Estado de canales |
| `agent-reach doctor --json` | Igual, parseable (`active_backend` manda) |
| `agent-reach install --env=auto --dry-run` | Preview de cambios de sistema |
| `agent-reach check-update` | Revisa versión nueva |
| `agent-reach configure proxy` | Guarda proxy (entrada oculta) |

Guía upstream: https://raw.githubusercontent.com/Panniantong/agent-reach/main/docs/install.md
