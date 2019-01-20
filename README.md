# docker-frontal

Docker project to configure a **web frontal** service for **docker swarm** with automatic ssl - powered by [letsencrypt](https://letsencrypt.org/).

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
      frontal.path: /db
      frontal.https_port: 443
      frontal.http_port: 80
      frontal.port: 8080
      frontal.tls: force
  
```

## Labels
* `frontal.domain` the (sub)domain pointed to the host(s) to access from outside (mandatory)
* `frontal.path` the path for access from outside (optional, default `/`)
* `frontal.https_port` the secure port open to outside (optional, default `443`)
* `frontal.http_port` the insecure port open to outside (optional, default `80`)
* `frontal.port` the service port open in the service (mandatory)
* `frontal.tls` the type of ssl, the allowed options are (optional, default `force`):
  - `force` will redirect requests going to `insecure_port` to `secure_port` with `301 - Redirect Permanent`
  - `yes` will respond in both ports `insecure_port` and `secure_port` but it will not redirect. 
  - `no` will only respond to the `insecure_port`
  - `only` will only respond to the `secure_port`
