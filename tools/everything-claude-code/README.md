# Everything Claude Code (ECC)

Instalador y notas de operación para [Everything Claude Code](https://github.com/affaan-m/everything-claude-code),
la colección de agents / skills / commands / rules / hooks de Affaan Mustafa.
El zip que se pidió instalar es el fork de traducción al chino
[xu-xiang/everything-claude-code-zh](https://github.com/xu-xiang/everything-claude-code-zh).

## Antes de usarlo: dos cosas que conviene saber

**1. La versión `-zh` está congelada y atrasada dos versiones mayores.**
Verificado contra ambos repos el 2026-08-26:

| | zh (`dfbf946`, 2026-03-05) | upstream inglés (`main`, 2026-08-19) |
|---|---|---|
| versión | 1.7.0 | 2.2.0 |
| skills | 58 | 286 |
| agents | 14 | 68 |
| commands | 35 | 94 |

El zip entregado es idéntico al `HEAD` del fork zh: el proyecto de traducción no
tiene commits desde marzo. Además traduce las `description:` del frontmatter al
chino, y esa descripción es justo el texto contra el que Claude decide si activa
una skill. Nadie en Pax trabaja en chino. `--source en` instala el upstream
inglés y actualizado con el mismo set curado.

**2. El bundle es casi todo ingeniería de software, no finanzas.**
De las 58 skills del zh, la mayoría son Go, Django, Spring Boot, Swift, C++,
ClickHouse, Docker, patrones de frontend. Lo que roza el trabajo de un fondo son
cinco: `market-research`, `investor-materials`, `investor-outreach`,
`article-writing`, `content-engine` — y las tres primeras están escritas para
*founders levantando capital* (pitch decks, aplicaciones a aceleradoras, cold
emails a ángeles y VCs), no para el lado comprador: no hay memo de IC, ni LBO,
ni due diligence de M&A, ni valuación. Sirven por su disciplina de estructura y
de citar fuentes, no por su contenido.

Cada skill instalada cuesta contexto en **toda** sesión (su descripción entra al
índice que Claude lee al arrancar). Por eso el instalador es curado por defecto.

## Instalación

```bash
./install.sh                     # set curado -> ~/.claude          (fuente zh, pineada)
./install.sh --scope repo        # set curado -> <repo>/.claude      (persiste en git)
./install.sh --source en         # upstream inglés v2.2.0, mismo set curado
./install.sh --set full          # las 58 skills / 14 agents / 35 commands
./install.sh --stage-hooks       # deja los hooks en disco, DESACTIVADOS
./install.sh --dry-run           # muestra qué copiaría, no escribe
```

Los flags se combinan. `ECC_ZH_REF` / `ECC_EN_REF` cambian el commit clonado;
`ECC_DEST` cambia el destino.

`--scope home` instala en `~/.claude` (skills, agents, commands y `rules/`).
`--scope repo` instala en el `.claude/` de este repo — **es el único modo que
sobrevive** en los contenedores remotos de Claude Code, que son efímeros y
recrean `~/.claude` en cada sesión. Ese modo ya está aplicado y commiteado.

La copia es por elemento, no por directorio: instalar no borra skills propias
que ya estuvieran en el destino.

## Qué quedó instalado en este repo (`.claude/`)

11 skills, 7 agents, 9 commands. Verificado en vivo: Claude Code las carga.

| Grupo | Contenido |
|---|---|
| skills | `market-research`, `investor-materials`, `investor-outreach`, `article-writing`, `content-engine`, `search-first`, `iterative-retrieval`, `verification-loop`, `coding-standards`, `python-patterns`, `python-testing` |
| agents | `architect`, `planner`, `code-reviewer`, `security-reviewer`, `python-reviewer`, `doc-updater`, `tdd-guide` |
| commands | `/plan`, `/code-review`, `/verify`, `/checkpoint`, `/learn`, `/skill-create`, `/test-coverage`, `/update-docs`, `/orchestrate` |

### Excluido a propósito

| Qué | Por qué |
|---|---|
| **Todos los hooks** | Código de terceros que corre en **cada** tool call. `observe.sh` escribe en disco en cada llamada; otro bloquea `npm run dev` fuera de tmux; otros corren `tsc` y formateadores después de cada edición. Nada de eso aplica a este repo y sí abre superficie. `--stage-hooks` los deja en disco sin activarlos; activarlos exige editar `settings.json` a mano y leerlos antes. |
| `security-review` (skill) | Choca de nombre con la skill nativa de Claude Code, que gana. El archivo quedaría muerto. Usar la nativa: `/security-review`. |
| `security-scan` | Depende de AgentShield, una herramienta externa que no está instalada. |
| `strategic-compact`, `skill-stocktake` | Asumen hooks activos y rutas `~/.claude/…`; en scope repo no funcionan. Disponibles con `--set full --scope home`. |
| `chief-of-staff` (agent) | Triage de email/Slack/LINE/Messenger apoyado en hooks que no se instalan. |
| `rules/` en scope repo | Claude Code solo lee `rules/` desde `~/.claude/rules` o si un `CLAUDE.md` las referencia. Instalarlas en el repo crearía referencias muertas. Van solo en `--scope home`. |
| Todo lo de Cursor / Codex / OpenCode / `.agents` | El equipo usa Claude Code. |
| `assets/`, `docs/`, `translation_workdir/` | 19 MB de imágenes, video y caché de traducción. Cero valor operativo. |

### Referencias muertas que trae el upstream

- `search-first` y `verification-loop` invocan un agent `researcher` que **no
  existe** en la v1.7.0 (bug del upstream, no de esta instalación). Claude
  degrada al agent genérico.
- `/plan` apunta a `~/.claude/agents/planner.md` y `/learn` escribe en
  `~/.claude/skills/learned/`. Con `--scope repo` el agent se resuelve por
  nombre igual, pero lo que `/learn` guarde en `~/.claude` se pierde al
  reciclarse el contenedor. Para que persista hay que commitearlo.
- `/verify` y `/orchestrate` no existen en el upstream inglés v2.2.0: con
  `--source en` el instalador los reporta como `falta (skip)`.

## Riesgos

- **Código de terceros con permisos de ejecución.** ECC son ~4 MB de prompts,
  scripts de Node y hooks de shell de un repo de un solo autor (23 MB con
  imágenes y caché de traducción). Los prompts son
  inertes hasta que se activan; los hooks no. Se instalan los prompts, no los
  hooks.
- **Prompts que definen comportamiento.** Un agent puede correr comandos o
  escribir archivos, según lo que declare en su frontmatter. De los 7
  instalados, solo 2 son de lectura pura:

  | Agent | `tools` declarados |
  |---|---|
  | `architect`, `planner` | `Read`, `Grep`, `Glob` |
  | `code-reviewer`, `python-reviewer` | + `Bash` |
  | `tdd-guide` | `Read`, `Write`, `Edit`, `Bash`, `Grep` |
  | `doc-updater`, `security-reviewer` | `Read`, `Write`, `Edit`, `Bash`, `Grep`, `Glob` |

  Que `security-reviewer` pueda escribir y ejecutar es contraintuitivo para algo
  que se llama "reviewer": no audita, también parcha. Revisar el frontmatter de
  cualquier agent antes de ampliar el set.
- **Instalación desde un commit pineado, no un tag firmado.** `ECC_ZH_REF` está
  fijo en `dfbf946` para que un cambio silencioso en `main` no entre sin
  revisión. `--source en` usa `main` y sí puede moverse entre corridas.
- **Licencia MIT**, sin restricción de uso comercial.

## Recomendación

Quedarse con el set curado. Si va a crecer, crecer con `--source en` (v2.2.0,
286 skills, descripciones en inglés) y agregando skills de una en una a
`CURATED_SKILLS` en `install.sh`, no con `--set full`. Lo que de verdad le
falta a Pax — memo de IC, modelo LBO, DD de M&A, comparables — no está en ECC ni
en inglés: eso hay que escribirlo, y el `/skill-create` de este bundle es un
punto de partida razonable para hacerlo.
