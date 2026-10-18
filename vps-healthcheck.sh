#!/usr/bin/env bash
# vps-healthcheck.sh — read-only health check for a Linux web server (Ubuntu/Debian).
# It changes nothing on the server: it only reads system state and prints a Markdown report.
#
# Usage:  sudo ./vps-healthcheck.sh            # report to stdout
#         sudo ./vps-healthcheck.sh > report.md
#
# Checks: disk & inodes, memory, load, failed services, listening ports, Nginx/Apache config,
# SSL certificate expiry, PHP-FPM, recent web server errors, SSH hardening, firewall,
# pending updates, cron jobs.

set -u

DISK_WARN=85        # % used
CERT_WARN_DAYS=14   # days before expiry
ERR_LINES=20        # recent error lines to show

ok=0; warn=0; fail=0
line()  { printf '%s\n' "$*"; }
okm()   { ok=$((ok+1));   line "- ✅ $*"; }
warnm() { warn=$((warn+1)); line "- ⚠️ $*"; }
failm() { fail=$((fail+1)); line "- ❌ $*"; }
have()  { command -v "$1" >/dev/null 2>&1; }
section(){ line ""; line "## $*"; line ""; }

line "# Server health report — $(hostname) — $(date -u '+%Y-%m-%d %H:%M UTC')"
line ""
if [ -r /etc/os-release ]; then . /etc/os-release; line "**OS:** ${PRETTY_NAME:-unknown} · **Kernel:** $(uname -r)"; fi
[ "$(id -u)" -ne 0 ] && line "" && line "> Not running as root: some checks may be incomplete."

section "Resources"
while read -r fs size used avail pct mnt; do
  p=${pct%\%}
  if [ "$p" -ge "$DISK_WARN" ]; then failm "Disk $mnt at ${pct} (${avail} free)"; else okm "Disk $mnt at ${pct}"; fi
done < <(df -hP -x tmpfs -x devtmpfs -x overlay 2>/dev/null | awk 'NR>1{print $1,$2,$3,$4,$5,$6}')
while read -r mnt ipct; do
  p=${ipct%\%}; [ "$p" = "-" ] && continue
  [ "$p" -ge "$DISK_WARN" ] && failm "Inodes on $mnt at ${ipct} (many small files: sessions, cache, mail queue?)"
done < <(df -iP -x tmpfs -x devtmpfs -x overlay 2>/dev/null | awk 'NR>1{print $6,$5}')
if have free; then
  read -r _ mt mu _ < <(free -m | awk '/^Mem:/{print $1,$2,$3,$7}')
  mavail=$(free -m | awk '/^Mem:/{print $7}')
  pct=$(( (mt-mavail)*100/mt ))
  if [ "$pct" -ge 90 ]; then warnm "Memory ${pct}% used (${mavail} MB available of ${mt} MB)"; else okm "Memory ${pct}% used (${mavail} MB available)"; fi
  swap=$(free -m | awk '/^Swap:/{print $2}'); [ "${swap:-0}" -eq 0 ] && warnm "No swap configured (risk of OOM kills on small VPS)"
fi
cores=$(nproc 2>/dev/null || echo 1); load=$(cut -d' ' -f1 /proc/loadavg)
if awk -v l="$load" -v c="$cores" 'BEGIN{exit !(l>c)}'; then warnm "Load average $load on $cores core(s)"; else okm "Load average $load on $cores core(s)"; fi

section "Services"
if have systemctl && systemctl is-system-running >/dev/null 2>&1 || [ "$(systemctl is-system-running 2>/dev/null)" = "degraded" ]; then
  failed=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}')
  if [ -n "$failed" ]; then for u in $failed; do failm "Failed unit: $u"; done; else okm "No failed systemd units"; fi
else
  line "- ℹ️ systemd not available (container?): service state not checked"
fi
if have ss; then
  line ""; line "Listening TCP ports:"; line '```'; ss -tlnp 2>/dev/null | awk 'NR>1{print $4, $6}' | sort -u; line '```'
fi

section "Web server"
certs=""
if have nginx; then
  if out=$(nginx -t 2>&1); then okm "nginx -t: configuration OK"; else failm "nginx -t failed:"; line '```'; line "$out"; line '```'; fi
  pgrep -x nginx >/dev/null && okm "Nginx is running" || failm "Nginx is installed but not running"
  active=$(nginx -T 2>/dev/null | sed 's/#.*//')   # effective config, comments stripped
  certs="$certs $(printf '%s\n' "$active" | grep -oE 'ssl_certificate[[:space:]]+[^;]+' | awk '{print $2}')"
  for sock in $(printf '%s\n' "$active" | grep -oE 'fastcgi_pass[[:space:]]+unix:[^;]+' | sed 's/.*unix://' | sort -u); do
    [ -S "$sock" ] && okm "PHP-FPM socket used by Nginx exists: $sock" || failm "Nginx points to $sock but the socket does not exist (PHP-FPM down or wrong version → 502 errors)"
  done
  for log in /var/log/nginx/error.log; do
    [ -r "$log" ] || continue
    n=$(grep -cE '\[(error|crit|alert|emerg)\]' "$log" 2>/dev/null || true)
    if [ "${n:-0}" -gt 0 ]; then warnm "$n error lines in $log (last $ERR_LINES below)"; line '```'; grep -E '\[(error|crit|alert|emerg)\]' "$log" | tail -n "$ERR_LINES"; line '```'; else okm "No errors in $log"; fi
  done
fi
if have apache2ctl; then
  if out=$(apache2ctl configtest 2>&1); then okm "apache2ctl configtest: Syntax OK"; else failm "Apache config test failed:"; line '```'; line "$out"; line '```'; fi
  certs="$certs $(grep -rhoE 'SSLCertificateFile[[:space:]]+\S+' /etc/apache2 2>/dev/null | awk '{print $2}')"
fi
have nginx || have apache2ctl || line "- ℹ️ No Nginx or Apache found"
for s in $(ls /run/php/*.sock 2>/dev/null); do okm "PHP-FPM socket present: $s"; done

section "SSL certificates"
found=0
for c in $(printf '%s\n' $certs /etc/letsencrypt/live/*/fullchain.pem | sort -u); do
  [ -r "$c" ] || continue; found=1
  end=$(openssl x509 -enddate -noout -in "$c" 2>/dev/null | cut -d= -f2) || continue
  cn=$(openssl x509 -subject -noout -in "$c" 2>/dev/null | sed 's/.*CN *= *//')
  days=$(( ( $(date -d "$end" +%s) - $(date +%s) ) / 86400 ))
  if [ "$days" -lt 0 ]; then failm "$cn: EXPIRED $(( -days )) day(s) ago ($c)"
  elif [ "$days" -lt "$CERT_WARN_DAYS" ]; then warnm "$cn: expires in $days day(s) ($c)"
  else okm "$cn: valid for $days more day(s)"; fi
done
[ "$found" -eq 0 ] && line "- ℹ️ No certificate files found"
if have certbot; then systemctl list-timers 2>/dev/null | grep -q certbot && okm "certbot renewal timer active" || warnm "certbot installed but no renewal timer found"; fi

section "Security"
sshd=/etc/ssh/sshd_config
if [ -r "$sshd" ]; then
  eff() { (sshd -T 2>/dev/null || cat "$sshd") | awk -v k="$1" 'tolower($1)==tolower(k){print tolower($2); exit}'; }
  prl=$(eff PermitRootLogin); pa=$(eff PasswordAuthentication)
  [ "$prl" = "yes" ] && warnm "SSH: PermitRootLogin yes (prefer prohibit-password or no)" || okm "SSH: PermitRootLogin ${prl:-default}"
  [ "$pa" = "yes" ] && warnm "SSH: PasswordAuthentication yes (prefer key-only)" || okm "SSH: PasswordAuthentication ${pa:-default}"
else line "- ℹ️ No sshd_config found"; fi
if have ufw; then ufw status 2>/dev/null | grep -q 'Status: active' && okm "UFW firewall active" || warnm "UFW installed but inactive"
else warnm "No UFW firewall found (check provider firewall / iptables)"; fi
if have apt; then
  up=$(apt list --upgradable 2>/dev/null | grep -c upgradable || true); sec=$(apt list --upgradable 2>/dev/null | grep -c -i security || true)
  [ "${sec:-0}" -gt 0 ] && warnm "$up package(s) upgradable, $sec from security repos" || okm "$up package(s) upgradable (none flagged as security)"
fi

section "Scheduled tasks"
line '```'; for f in /etc/crontab /etc/cron.d/*; do [ -r "$f" ] && grep -vE '^\s*(#|$)' "$f" | sed "s|^|$f: |"; done; crontab -l 2>/dev/null | grep -vE '^\s*(#|$)' | sed 's|^|root: |'; line '```'

section "Summary"
line "**$ok OK · $warn warnings · $fail problems**"
[ "$fail" -gt 0 ] && exit 2 || exit 0
