# Agent Reach

Instalador y notas de operación para [Agent Reach](https://github.com/Panniantong/agent-reach)
v1.5.0 — un selector/instalador/router que le da a un agente acceso de lectura a
plataformas externas (web, YouTube, GitHub, RSS, Exa, Twitter/X, Reddit, XHS,
Bilibili, Xueqiu, LinkedIn, Facebook, Instagram). No es un wrapper: instala las
CLIs upstream y el agente las llama directo.

## Instalación

```bash
./install.sh              # instala + chequeo read-only (no toca el sistema)
./install.sh --dry-run    # muestra qué haría --system
./install.sh --system     # permite instalar dependencias de sistema (gh, mcporter)
```

Queda en `~/.agent-reach-venv`, con symlink en `~/.local/bin/agent-reach`.
Config y tokens en `~/.agent-reach/`. Nada se escribe dentro de este repo.

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

## Riesgos antes de configurar canales

- **Cookies = acceso total a la cuenta.** Twitter, Reddit, XHS, Facebook,
  Instagram y Xueqiu se autentican con la cookie de sesión del navegador,
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
  superficie. Aprobar canal por canal, no en bloque.

## Comandos útiles

| Comando | Qué hace |
|---|---|
| `agent-reach doctor` | Estado de canales |
| `agent-reach doctor --json` | Igual, parseable (`active_backend` manda) |
| `agent-reach install --env=auto --dry-run` | Preview de cambios de sistema |
| `agent-reach check-update` | Revisa versión nueva |
| `agent-reach configure proxy` | Guarda proxy (entrada oculta) |

Guía upstream: https://raw.githubusercontent.com/Panniantong/agent-reach/main/docs/install.md
