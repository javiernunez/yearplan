# yearplan.sermestre.es

Programación **Monster Builders** como web estática.

- Entrada: `index.html` → `programacion_index.html`
- Autodeploy: push a `master` / `main` → GitHub Actions sincroniza ficheros al servidor (`rsync`, sin `git pull` en el VPS)

## Qué tienes que configurar tú (una vez)

### 1. Secretos del repo GitHub (`yearplan`)

En **Settings → Secrets and variables → Actions**, añade los mismos (o equivalentes) que usa `sermestre`:

| Nombre | Valor |
| --- | --- |
| `DEPLOY_HOST` | IP o hostname del VPS |
| `DEPLOY_USER` | usuario SSH (**`root`** si el sitio está en `/opt/…` clonado como root) |
| `DEPLOY_SSH_KEY` | clave privada SSH (como en sermestre) |
| `DEPLOY_PORT` | opcional, por defecto `22` |
| `DEPLOY_PATH` | opcional, por defecto `/opt/yearplan.sermestre.es` |

### 2. DNS

En el DNS de `sermestre.es`, crea un registro **A** (o CNAME) de `yearplan` apuntando al mismo servidor que `sermestre.es`.

### 3. Primera clonación en el servidor

El Action sincroniza por `rsync`; el directorio en el servidor debe existir y ser escribible por `DEPLOY_USER` (típicamente `root`). Setup inicial:

```bash
sudo mkdir -p /opt/yearplan.sermestre.es
sudo chown "$USER":"$USER" /opt/yearplan.sermestre.es
git clone git@github.com:javiernunez/yearplan.git /opt/yearplan.sermestre.es
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
