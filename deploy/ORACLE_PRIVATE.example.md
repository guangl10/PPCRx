# Oracle server ops (PRIVATE — do not commit)

Copy this file to `ORACLE_PRIVATE.md` in the same directory and fill in values.
`ORACLE_PRIVATE.md` is gitignored and must never be pushed to the public GitHub repo.

## Public URLs

| URL | Notes |
|-----|--------|
| https://guanglab.org/ppcrx/ | Canonical HTTPS |

## Server (fill in)

- **Host:** (e.g. Oracle Cloud ARM)
- **App directory:** `/srv/shiny-server/...`
- **Dev checkout:** `/home/ubuntu/ppc_rx_app`
- **Service:** `ppcsexrx-shiny.service`

### Deploy checkout → production

```bash
sudo rsync -a --delete --exclude='.git' /path/to/checkout/ /srv/shiny-server/PPCSexRx/
sudo systemctl restart ppcsexrx-shiny.service
```

## GitHub push

Remote: `git@github.com:guangl10/PPCRx.git`

Use a **Deploy Key** with write access or `gh auth login`.
Do **not** paste private keys or PATs into tracked files.

See your local `ORACLE_PRIVATE.md` for server-specific keys and paths.
