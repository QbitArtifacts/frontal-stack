# docker-web-frontal

![](https://img.shields.io/docker/pulls/qbitartifacts/web-frontal.svg)
![](https://img.shields.io/docker/stars/qbitartifacts/web-frontal.svg)
![](https://img.shields.io/microbadger/image-size/qbitartifacts/web-frontal.svg)
![](https://img.shields.io/microbadger/layers/qbitartifacts/web-frontal.svg)
![](https://img.shields.io/docker/automated/qbitartifacts/web-frontal.svg)

Docker project to configure a `http/https` **web frontal** service for **docker swarm** with automatic ssl - powered
by [HAProxy](http://www.haproxy.org/),  [letsencrypt](https://letsencrypt.org/) and [crond](https://en.wikipedia.org/wiki/Cron).

## Description
The `frontal` service uses the docker endpoint `/var/run/docker.sock` to get the list of services and checks for the labels
`frontal.*` (described below), then uses the letsencrypt service to create the certificates, and then installs a
cron service to renew the certs periodically.

## Limits
Some notes we have to take into account
* [Letsencrypt rate limits](https://letsencrypt.org/docs/rate-limits/)
  
  If we deploy a service with multiple instances we have to know that each instance will query letsencrypt servers
  to create/renew the certificates, so it maybe exceeds the rate limits, one (semi)solution is to scale the service
  leaving some time between scales, and for the renewals it will not be a problem because the cron renew is setup
  randomly. Another solution can be copy or share a volume between containers.

## Sample configuration

```yaml
# file: example-stack.yml
# This example starts a mariadb server and adminer on url https://admin.example.com/db
version: "3.7"

volumes:
  certs:

services:
  frontal:
    image: qbitartifacts/web-frontal
    environment:
      - LE_EMAIL=admin@example.com
      - LE_AGREE_TOS=yes
      - LE_MODE=test
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - certs:/etc/letsencrypt
    ports:
      - 80:80
      - 443:443
    deploy:
      placement:
        constraints:
          - node.role == manager
  db:
    image: mariadb
    environment:
      - MYSQL_ROOT_PASSWORD=example
  admin:
    image: adminer
    labels:
      frontal.domain: admin.example.com
      frontal.path: /db
      frontal.target.port: 8080
      frontal.tls: force
  
```
## Environment variables
* `LE_EMAIL` the letsencrypt notification email
* `LE_AGREE_TOS` you have to tell the service if it have to agree or not the
[Letsencrypt Terms Of Service](https://letsencrypt.org/repository/), if it is not agreed the certificate issuing
will not work.
* `LE_MODE` tells the service to use the letsencrypt test service or not, options are `test` and `prod` (default `prod`)

## Service labels
* `frontal.domain` the (sub)domain pointed to the host(s) to access from outside (mandatory)
* `frontal.path` the path for access from outside (optional, default `/`)
* `frontal.target.port` the service port open in the service (mandatory)
* `frontal.tls` the type of [tls](https://en.wikipedia.org/wiki/Transport_Layer_Security),
the allowed options are (optional, default `force`):
  - `force` will redirect requests going to port `80` to `443` with `302 - Found`
  - `yes` will respond in both ports `80` and `443` but it will not redirect. 
  - `no` will only respond to port `80`
  - `only` will only respond to port `443`
