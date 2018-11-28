FROM haproxy
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
ENTRYPOINT ./docker-entrypoint.sh
