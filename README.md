# vps-healthcheck

A **read-only** health check for Linux web servers (Ubuntu/Debian with Nginx or Apache).
One script, no dependencies, prints a Markdown report you can paste into a ticket.
It never changes anything on the server.

```bash
curl -O https://raw.githubusercontent.com/dev-tomatoweb/vps-healthcheck/main/vps-healthcheck.sh
sudo bash vps-healthcheck.sh > report.md
```

Exit code: `0` = no problems, `2` = at least one problem found (handy for cron or CI).

## What it checks

| Area | Checks |
|---|---|
| Resources | disk and inode usage, memory, swap, load average |
| Services | failed systemd units, listening TCP ports |
| Web server | `nginx -t` / `apache2ctl configtest`, Nginx running, PHP-FPM sockets referenced by the **active** Nginx config actually exist, recent `error`/`crit` lines in the error log |
| SSL | expiry of every certificate used by Nginx/Apache and Let's Encrypt, certbot renewal timer |
| Security | SSH `PermitRootLogin` / `PasswordAuthentication`, UFW status, pending (security) updates |
| Scheduled tasks | system and root cron jobs |

## Example

Output from the test container in [`test/`](test/) — an Nginx site whose certificate expires in a few days and whose
PHP-FPM socket is missing (the classic cause of **502 Bad Gateway** after a PHP upgrade):

```
## Web server
- ✅ nginx -t: configuration OK
- ✅ Nginx is running
- ❌ Nginx points to /run/php/php8.3-fpm.sock but the socket does not exist (PHP-FPM down or wrong version → 502 errors)
- ⚠️ 2 error lines in /var/log/nginx/error.log

## SSL certificates
- ⚠️ shop.example.test: expires in 4 day(s) (/etc/ssl/demo/cert.pem)

## Security
- ⚠️ SSH: PermitRootLogin yes (prefer prohibit-password or no)
- ⚠️ UFW installed but inactive

**7 OK · 4 warnings · 1 problems**
```

Full report: [`sample-report.md`](sample-report.md).

## Try it locally

```bash
docker build -f test/Dockerfile -t vps-healthcheck-test .
docker run --rm vps-healthcheck-test
```

## License

MIT — Marco Perricone (tomatoweb)
