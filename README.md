# yearplan.sermestre.es

Programación **Monster Builders** como web estática.

- Entrada: `index.html` → `programacion_index.html`
- Autodeploy: push a `master` / `main` → GitHub Actions hace `git pull` en el VPS (~segundos)

## Qué tienes que configurar tú (una vez)

### 1. Secretos del repo GitHub (`yearplan`)

En **Settings → Secrets and variables → Actions**:

| Nombre | Valor |
| --- | --- |
| `DEPLOY_HOST` | IP o hostname del VPS |
| `DEPLOY_USER` | Usuario SSH que **posee** `/opt/yearplan.sermestre.es` (p. ej. `deploy`) |
| `DEPLOY_SSH_KEY` | clave privada de ese usuario |
| `DEPLOY_PORT` | opcional, por defecto `22` |
| `DEPLOY_PATH` | opcional, por defecto `/opt/yearplan.sermestre.es` |

`DEPLOY_USER` y el dueño del directorio en el VPS tienen que coincidir. Si clonaste como root pero el Action usa `deploy`, en el VPS (como root): `chown -R deploy:deploy /opt/yearplan.sermestre.es`.

### 2. DNS

En el DNS de `sermestre.es`, crea un registro **A** (o CNAME) de `yearplan` apuntando al mismo servidor que `sermestre.es`.

### 3. Primera clonación en el servidor

El Action hace `git pull` en el servidor. Clona con el **mismo usuario** que usarás en `DEPLOY_USER`:

```bash
sudo mkdir -p /opt/yearplan.sermestre.es
sudo chown deploy:deploy /opt/yearplan.sermestre.es   # o tu DEPLOY_USER
sudo -u deploy git clone git@github.com:javiernunez/yearplan.git /opt/yearplan.sermestre.es
```

Si el repo **ya está clonado como root**, no hace falta reclonar — solo:

```bash
chown -R deploy:deploy /opt/yearplan.sermestre.es
```

El servidor necesita acceso de lectura al repo (deploy key de solo lectura o la misma clave que ya usa para `sermestre`).

### 4. Nginx + HTTPS

```bash
cd /opt/yearplan.sermestre.es
sudo cp deploy/nginx-yearplan.sermestre.es.conf /etc/nginx/sites-available/yearplan.sermestre.es
sudo ln -sf /etc/nginx/sites-available/yearplan.sermestre.es /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d yearplan.sermestre.es
```

### 5. PDFs grandes de cuentos (fuera de git)

GitHub no admite ficheros ≥ 100 MiB. Estos PDF **no** van en el repo (el flipbook usa `CUENTOS/pages/*.jpg`):

- `CUENTOS/LS4*.pdf`
- `CUENTOS/LS6 Melody Moo's Busy Weather Day.pdf`
- `CUENTOS/LS8*.pdf`

Si quieres el botón «Open PDF» de esas historias, súbelos una vez al servidor:

```bash
rsync -avz "CUENTOS/LS4"*.pdf "CUENTOS/LS6 Melody Moo's Busy Weather Day.pdf" "CUENTOS/LS8"*.pdf \
  user@SERVIDOR:/opt/yearplan.sermestre.es/CUENTOS/
```

## Deploy manual

En GitHub: **Actions → Deploy → Run workflow**.

O en el servidor:

```bash
DEPLOY_PATH=/opt/yearplan.sermestre.es bash scripts/remote-deploy.sh
```

## Contraseña de acceso (HTTP Basic Auth)

La web es estática; la protección va en **Caddy** (producción) leyendo un `.env` **solo en el VPS** (no en git).

### 1. Caddy (recomendado)

En el Caddyfile principal del servidor, importa el bloque del repo (una vez):

```
import /opt/yearplan.sermestre.es/deploy/yearplan.caddy
```

Si el sitio ya está definido a mano, añade dentro del bloque `yearplan.sermestre.es`:

```
import /opt/yearplan.sermestre.es/deploy/caddy.d/*.caddy
```

### 2. Crear `.env` en el VPS

```bash
cd /opt/yearplan.sermestre.es
cp .env.example .env
chmod 600 .env
# Edita YEARPLAN_AUTH_USER y YEARPLAN_AUTH_PASSWORD
bash scripts/sync-site-auth.sh
sudo systemctl reload caddy
```

Variables:

| Variable | Uso |
| --- | --- |
| `YEARPLAN_AUTH_USER` | Usuario del popup del navegador |
| `YEARPLAN_AUTH_PASSWORD` | Contraseña en texto plano (solo en disco del VPS) |

El script genera `deploy/caddy.d/10-basicauth.caddy` (gitignored). Si borras `.env` o dejas la contraseña vacía, el sitio vuelve a ser público.

Cada deploy (`git pull`) vuelve a ejecutar el script si existe `.env`. Para recargar Caddy sin sudo interactivo, el usuario `deploy` puede tener:

```
deploy ALL=(root) NOPASSWD: /bin/systemctl reload caddy
```

### 3. nginx (alternativa)

Descomenta `auth_basic` en `deploy/nginx-yearplan.sermestre.es.conf`, ejecuta `sync-site-auth.sh` (genera `deploy/.htpasswd`) y `sudo systemctl reload nginx`.
