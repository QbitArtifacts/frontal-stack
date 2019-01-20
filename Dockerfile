FROM debian:buster
ENV DEBIAN_FRONTEND noninteractive
RUN apt update && apt install -y haproxy cron certbot jq apt-transport-https ca-certificates curl gnupg2 software-properties-common
RUN curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | apt-key add -
RUN add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") $(lsb_release -cs) stable"
RUN apt update && apt install -y docker-ce-cli
COPY haproxy.cfg /etc/haproxy/haproxy.cfg
WORKDIR /
COPY docker-entrypoint.sh /
CMD /docker-entrypoint.sh
