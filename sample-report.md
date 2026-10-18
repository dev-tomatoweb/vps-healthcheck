# Server health report — fdf322cdf87a — 2026-10-18 18:48 UTC

**OS:** Ubuntu 24.04.5 LTS · **Kernel:** 6.12.76-linuxkit

## Resources

- ✅ Disk /etc/hosts at 2%
- ✅ Memory 9% used (7173 MB available)
- ✅ Load average 0.18 on 12 core(s)

## Services

- ℹ️ systemd not available (container?): service state not checked

Listening TCP ports:
```
0.0.0.0:443 users:(("nginx",pid=8,fd=7))
0.0.0.0:80 users:(("nginx",pid=8,fd=5))
[::]:80 users:(("nginx",pid=8,fd=6))
```

## Web server

- ✅ nginx -t: configuration OK
- ✅ Nginx is running
- ❌ Nginx points to /run/php/php8.3-fpm.sock but the socket does not exist (PHP-FPM down or wrong version → 502 errors)
- ⚠️ 2 error lines in /var/log/nginx/error.log (last 20 below)
```
2026/10/18 09:12:01 [error] 812#812: *41 connect() to unix:/run/php/php8.3-fpm.sock failed (2: No such file or directory) while connecting to upstream
2026/10/18 09:12:07 [crit] 812#812: *44 SSL_do_handshake() failed
```

## SSL certificates

- ⚠️ shop.example.test: expires in 4 day(s) (/etc/ssl/demo/cert.pem)

## Security

- ⚠️ SSH: PermitRootLogin yes (prefer prohibit-password or no)
- ✅ SSH: PasswordAuthentication default
- ⚠️ UFW installed but inactive
- ✅ 0 package(s) upgradable (none flagged as security)

## Scheduled tasks

```
/etc/crontab: SHELL=/bin/sh
/etc/crontab: 17 *	* * *	root	cd / && run-parts --report /etc/cron.hourly
/etc/crontab: 25 6	* * *	root	test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.daily; }
/etc/crontab: 47 6	* * 7	root	test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.weekly; }
/etc/crontab: 52 6	1 * *	root	test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.monthly; }
/etc/cron.d/backup: 17 3 * * * root /usr/local/bin/backup.sh
/etc/cron.d/e2scrub_all: 30 3 * * 0 root test -e /run/systemd/system || SERVICE_MODE=1 /usr/lib/aarch64-linux-gnu/e2fsprogs/e2scrub_all_cron
/etc/cron.d/e2scrub_all: 10 3 * * * root test -e /run/systemd/system || SERVICE_MODE=1 /sbin/e2scrub_all -A -r
```

## Summary

**7 OK · 4 warnings · 1 problems**
