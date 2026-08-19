# Monster Builders — contexto para IA

Sitio estático de la **programación de aula** *Monster Builders* (inglés de 3.º de Primaria). Autora: **Carla Mortes Pons**. No es una app con backend: es un Year Plan proyectable en clase (slides, ruleta, PDFs, cuentos, vídeos).

- Web: https://yearplan.sermestre.es
- Repo: `git@github.com:javiernunez/yearplan.git` (rama `master`)
- Entrada: `index.html` redirige a `programacion_index.html`

Si clonas este repo en otro portátil, este archivo es el contexto persistente. Léelo antes de tocar deploy, `CUENTOS/` o `.gitignore`.

## Por qué existe

Carla necesita la programación en un navegador (pizarra digital), no como un PDF suelto. Cada Learning Situation (LS 1–10) tiene diapositivas PNG, materiales, Plickers, canciones y un cuento de Melody Moo. El objetivo del repo es **publicar eso** de forma estable, no reescribir el Year Plan.

## Cómo está montado

| Qué | Dónde |
| --- | --- |
| Programación (HTML enorme + JS) | `programacion_index.html` |
| Ruleta | `monster_roulette_widget.html` |
| Flipbook de cuentos | `cuento_flipbook.html?ls=1` … `?ls=9` |
| Slides | `LS 1 POWERPOINT.pdf (1)/`, `LS 2 POWERPOINT/` … `LS 10 POWERPOINT/` (`File 00001.png` …) |
| Materiales enlazados | `padlet_files/`, `Feed me monster/`, `FAN & PICK PLICKERS/`, `SONGS/`, `assets/` |
| Deploy | `.github/workflows/deploy.yml` → SSH al VPS y `scripts/remote-deploy.sh` |

Push a `master`/`main` dispara GitHub Actions (no hay build step).

## GitHub Actions (deploy)

Workflow: `.github/workflows/deploy.yml` — job **Deploy static site to yearplan.sermestre.es**.

| Trigger | Qué pasa |
| --- | --- |
| Push a `master` o `main` | SSH al VPS → `git pull` (`scripts/remote-deploy.sh`) |
| **Actions → Deploy → Run workflow** | Mismo deploy manual |

**Secretos** (Settings → Secrets and variables → Actions): `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_KEY`; opcionales `DEPLOY_PORT` (default 22), `DEPLOY_PATH` (default `/opt/yearplan.sermestre.es`).

**Usuario SSH (`DEPLOY_USER`):** debe ser **dueño** de `DEPLOY_PATH` (incluido `.git`). Lo habitual:

| Setup | `DEPLOY_USER` | Una vez en el VPS |
| --- | --- | --- |
| **Recomendado** | `deploy` (u otro user sin root) | `chown -R deploy:deploy /opt/yearplan.sermestre.es` |
| Atajo | `root` | nada, si el clone ya es de root |

Si el clone es de root y el Action entra como `deploy` → `Permission denied` en `.git/FETCH_HEAD`. No es un bug del workflow: hay que alinear dueño del directorio y usuario SSH.

**`.git/objects` permission denied tras fetch:** si root hizo `git fetch` después del `chown`, creó ficheros en `.git/objects` como root. Vuelve a: `chown -R deploy:deploy /opt/yearplan.sermestre.es` (o tu `DEPLOY_USER`).

**Arreglo one-shot (como root en el VPS):**

```bash
# Si no existe el usuario deploy:
# adduser --disabled-password --gecos "" deploy

chown -R deploy:deploy /opt/yearplan.sermestre.es
# Clave pública del par DEPLOY_SSH_KEY en /home/deploy/.ssh/authorized_keys
```

En GitHub: `DEPLOY_USER=deploy` y `DEPLOY_SSH_KEY` = clave privada de ese usuario. Caddy/nginx solo **leen** los ficheros (644/755); no hace falta que el servicio web sea `deploy`.

**Por qué no rsync desde Actions:** el repo pesa ~2 GB. `actions/checkout` baja todo el commit en cada push (varios minutos). `git pull` en el VPS solo trae el delta (segundos).

**En el servidor:** `git fetch` + `reset --hard` + `clean -fd`; comprueba `index.html` y `programacion_index.html`. `safe.directory` configurado para Git ≥ 2.35.

**Concurrencia:** `concurrency: deploy-yearplan` — un deploy en curso cancela el anterior.

### Servidor

- SSH: `ssh hetzner` (root; clave `~/.ssh/yearplan_deploy`)
- Ruta: `/opt/yearplan.sermestre.es/`
- En producción responde **Caddy** (el repo también tiene un ejemplo nginx en `deploy/`)

**Trampa de 404:** si un archivo no existe, Caddy puede devolver `index.html` (465 bytes, `text/html`, redirect a la programación) con HTTP 200. Un HEAD/GET 200 **no** prueba que el PDF exista. Comprueba `Content-Type: application/pdf` y que el cuerpo empiece por `%PDF-`.

## Límite de tamaño de GitHub (100 MiB)

GitHub **rechaza** ficheros ≥ 100 MiB. Por eso los PDF enormes de cuentos **no van en git**. El flipbook en clase **no los necesita**: pasa páginas JPG.

Estos tres están en `CUENTOS/.gitignore` y solo viven en el disco local + (si se han subido) en el VPS:

| Archivo local | Tamaño aprox. |
| --- | --- |
| `CUENTOS/LS4 Melody Moo’s Monster Christmas.pdf` | 129 MB |
| `CUENTOS/LS6 Melody Moo's Busy Weather Day.pdf` | 120 MB |
| `CUENTOS/LS8 Melody Moo’s Easter Adventure.pdf` | 110 MB |

**No** intentes `git add` esos PDF. Si hace falta el botón «Open PDF» de LS4/6/8, súbelos **una vez** al servidor:

```bash
# desde la raíz del repo, en un Mac que sí tenga los PDF locales
rsync -avz --progress \
  CUENTOS/LS4*.pdf \
  "CUENTOS/LS6 Melody Moo's Busy Weather Day.pdf" \
  CUENTOS/LS8*.pdf \
  hetzner:/opt/yearplan.sermestre.es/CUENTOS/
```

Un `git pull` en el servidor **no** los borra (no están en el repo). `git clean -fd` del deploy tampoco debería tocarlos si no son untracked raros; igual, no limpies `CUENTOS/*.pdf` a mano en el VPS.

## Cuentos (Melody Moo)

Hay **dos capas**:

1. **Flipbook (lo que se usa en clase)**  
   Imágenes `CUENTOS/pages/LS{n}/page-01.jpg` … (unas 10–11 páginas). Textos overlay opcionales en `CUENTOS/texts/LS{n}.json`.
2. **PDF original (botón Open PDF)**  
   Nombres en `CUENTOS/story_pdfs.json` y en el objeto `PDFS` de `cuento_flipbook.html`. Tienen que coincidir **byte a byte** (espacios, `LS 5` vs `LS5`, apóstrofe recto `'` vs curvo `’`).

Estado conocido (agosto 2026):

- Flipbook JPG: LS1–LS9 en el servidor, OK.
- PDF en git/servidor: LS3 OK (~98 MB, bajo el límite). LS1 existe en local/servidor como `LS1 Melody Moo's Happy Song.pdf` (**apóstrofe recto**); el JSON/flipbook piden el **curvo** `’` → el botón Open PDF de LS1 falla.
- PDF grandes LS4/6/8: ignorados por git; hay que rsync (hecho al VPS el 19 ago 2026).
- PDF LS2, LS5, LS7, LS9: **no están** en la carpeta local `CUENTOS/` (nunca se subieron). El flipbook igual funciona con JPG.
- Textos overlay: hay `CUENTOS/texts/LS3.json`, `LS4`, `LS6`, `LS8`. Faltan LS1, 2, 5, 7, 9 (el libro se ve; no sale caption).

No sustituyas el flipbook JPG por incrustar los PDF de 100+ MB en el navegador.

## Qué está en `.gitignore` y por qué

Raíz (`.gitignore`):

- `*.py` — scripts locales de parcheo/restauración de slides; no forman parte del sitio.
- `NUEVOS POWERPOINTS/`, `posters/`, `EVALUATION/`, `ls3_eco_adapt/` — material de trabajo no enlazado desde la web.
- `versions/`, `programacion_index_BACKUP*.html` — historial local.
- `YP PROGRAMACION SUPER FINAL.pdf`, `GUION_YEAR_PLAN_20min_RECITABLE.*`, `Padlet - *.xlsx` — fuentes/export, no se sirven.
- `Abrir programacion.command`, `.DS_Store`, `*.docx`.

`CUENTOS/.gitignore`: solo los tres PDF ≥ 100 MiB (nombres exactos, incluido el apóstrofe).

Al publicar, no “arregles” el gitignore para meter esos PDF: GitHub los rechazará.

## Convenciones al editar

- Sitio estático: cambia HTML/CSS/JS/assets y haz push; no hay npm/build.
- No commits de secretos, `.env`, ni claves SSH.
- No force-push a `master`.
- No reescribas `programacion_index.html` entero si solo hay que tocar un enlace o un nombre de fichero.
- Nombres con espacios y apóstrofes: al probar URLs, hay que URL-encode; en disco el carácter tiene que ser el mismo que en `PDFS` / `story_pdfs.json`.
- Scripts Python: útiles en local, no los subas (están ignorados a propósito).

## Comprobar la web

```bash
curl -sI https://yearplan.sermestre.es/programacion_index.html
# Un PDF de verdad:
curl -sI "https://yearplan.sermestre.es/CUENTOS/LS3%20Melody%20Moo's%20Zero%20Waste%20Challenge.pdf"
# Si Content-Type es text/html y Content-Length es 465 → el fichero NO está (fallback al index).
```
