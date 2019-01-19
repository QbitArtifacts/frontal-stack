# docker-frontal

Docker project to configure a **web frontal** service for **docker swarm** with automatic ssl (powered by letsencrypt) easily.

## Sample configuration

```yaml
# file: stack.yml
# This example starts a mariadb server and phpmyadmin on domain admin.example.com
version: "3.7"
services:
  frontal:
    image: qbitartifacts/frontal
    environment:
      - LE_EMAIL=admin@example.com
      - LE_ACCEPT_TOS=yes
      - LE_EMAIL=admin@example.com
    ports:
      - 80:80
      - 443:443
  db:
    image: mariadb
    environment:
      - MYSQL_ROOT_PASSWORD=example
  admin:
    image: adminer
    labels:
      frontal.domain: admin.example.com
      frontal.secure_port: 443
      frontal.insecure_port: 80
      frontal.port: 8080
      frontal.tls: force
  
```

## Labels
* `frontal.domain` the (sub)domain pointed to the host(s) to access from outside
* `frontal.port` the service port
* `frontal.tls` the type of ssl, the allowed options are:
  - `force` will redirect requests going to `insecure_port` to `secure_port` with `301 - Redirect Permanent` 
  - `yes` will respond in both ports `insecure_port` and `secure_port` but it will not redirect. 
  - `no` will only respond to the `insecure_port`
  - `only` will only respond to the `secure_port`
