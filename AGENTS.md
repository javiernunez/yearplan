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
| Push a `master` o `main` | `rsync` desde el runner de GitHub al VPS (no hace `git pull` en el servidor) |
| **Actions → Deploy → Run workflow** | Mismo deploy manual |

**Secretos** (Settings → Secrets and variables → Actions): `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_KEY`; opcionales `DEPLOY_PORT` (default 22), `DEPLOY_PATH` (default `/opt/yearplan.sermestre.es`).

**Cómo despliega:** checkout en GitHub → `rsync --size-only` por SSH a `DEPLOY_PATH`. Solo sube ficheros cuyo **tamaño** cambió (deploy típico = segundos; el runner compara ~1800 paths pero casi no transfiere datos). **Sin `--delete`**: PDFs grandes solo en el VPS no se borran.

**`DEPLOY_USER` debe poder escribir** en `DEPLOY_PATH`. Si el clone inicial fue como **root**, pon `DEPLOY_USER=root` en los secretos (misma clave que `~/.ssh/yearplan_deploy`). Si el usuario del Action no es dueño de los ficheros → `Permission denied` al sincronizar.

**Deploy manual en el VPS** (solo si entras por SSH): `scripts/remote-deploy.sh` hace `git pull` allí; requiere permisos de escritura en `.git`. El CI **no** usa ese script.

**Fallos viejos (git pull en servidor):** `dubious ownership` o `cannot open .git/FETCH_HEAD: Permission denied` — evitados con rsync desde Actions; no hace falta arreglar `.git` en el VPS para publicar.

**Concurrencia:** `concurrency: deploy-yearplan` — un deploy en curso cancela el anterior.

**No tocar en el workflow:** no commitear secretos; la clave va solo en `DEPLOY_SSH_KEY`.

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
