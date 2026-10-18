FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq && apt-get install -y -qq nginx openssl procps iproute2 openssh-server ufw cron >/dev/null
RUN mkdir -p /etc/ssl/demo && openssl req -x509 -newkey rsa:2048 -nodes -days 5 -subj "/CN=shop.example.test" \
      -keyout /etc/ssl/demo/key.pem -out /etc/ssl/demo/cert.pem 2>/dev/null \
 && printf 'server {\n listen 443 ssl;\n server_name shop.example.test;\n ssl_certificate /etc/ssl/demo/cert.pem;\n ssl_certificate_key /etc/ssl/demo/key.pem;\n root /var/www/html;\n location ~ \\.php$ { fastcgi_pass unix:/run/php/php8.3-fpm.sock; }\n}\n' > /etc/nginx/sites-enabled/shop \
 && printf '2026/10/18 09:12:01 [error] 812#812: *41 connect() to unix:/run/php/php8.3-fpm.sock failed (2: No such file or directory) while connecting to upstream\n2026/10/18 09:12:07 [crit] 812#812: *44 SSL_do_handshake() failed\n' > /var/log/nginx/error.log \
 && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
 && echo '17 3 * * * root /usr/local/bin/backup.sh' > /etc/cron.d/backup
COPY vps-healthcheck.sh /usr/local/bin/vps-healthcheck.sh
CMD nginx && bash /usr/local/bin/vps-healthcheck.sh
