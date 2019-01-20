#!/usr/bin/env bash

export HAPROXY_CONFIG=/etc/haproxy/haproxy.cfg 
export HAPROXY_CONFIG_BACKENDS=/etc/haproxy/backends.cfg 
export SSL_DIR=/etc/ssl
export CRT_LIST=$SSL_DIR/crt-list.txt

echo -n $HAPROXY_CONFIG_BACKENDS

if ! test -f $SSL_DIR;then
  mkdir -p $SSL_DIR
fi

read_label(){
  service=$1
  label=$2
  default=$3
  value=`docker service inspect $service --format='{{json .Spec.TaskTemplate.ContainerSpec.Labels}}' | jq -r ".[\"$label\"]"`
  if [[ "$value" == "null" ]];then
    if [[ "$default" == "" ]];then
      echo null
      return
    fi
    echo $default
    return
  fi
  echo $value
}

throw_error(){
  msg=$1
  echo "error: $msg" >&2
  exit -2
}

mandatory(){
  variable=$1
  label=$2
  if [[ "$variable" == "null" ]];then
    throw_error "$label is mandatory"
  fi
}

cert_ok(){
  if ! certbot certificates 2>/dev/null | grep "Domains: .*`sed 's/\./\\./g' <<<$domain`.*";then
      return -1
  fi
  if certbot certificates 2>/dev/null | grep "Domains: .*`sed 's/\./\\./g' <<<$domain`.*" -A 3 | grep "INVALID";then
    return -1
  fi
  return 0
}

issue_cert(){
  domain=$1
  email=$2
  agree_tos=$3
  mode=$4
  if [[ "$agree_tos" == "yes" ]];then
    if [[ "$mode" == "test" ]];then
      certbot certonly --standalone -n --test-cert --agree-tos -m $email -d $domain
    else
      certbot certonly --standalone -n --agree-tos -m $email -d $domain
    fi
    return
  fi
  if [[ "$mode" == "test" ]];then
    certbot certonly --standalone -n --test-cert -m $email -d $domain
  else
    certbot certonly --standalone -n -m $email -d $domain
  fi
}

add_cert(){
  domain=$1
  list_file=$2
  cd /etc/letsencrypt/live/$domain
  cat fullchain.pem privkey.pem > $SSL_DIR/$domain.pem
  echo "$SSL_DIR/$domain.pem" >> $list_file
  cd -
}

generate_backend(){
  name=$1
  port=$2
  path=$3
  echo -e "backend $name"
  echo -e "  server $name $name:$port check"
  if [[ "$path" != "/" ]];then
      echo -e "  http-request redirect code 301 location drop-query append-slash if { path_reg ^$path$ }"
      echo -e "  http-request set-path %[path,regsub(^$path,/)] if { path_beg $path }"
  fi
}

generate_ssl_redirect(){
  domain=$1
  echo -e "  http-request redirect scheme https if !{ ssl_fc } { hdr(host) -i $domain }"
}

generate_link(){
  domain=$1
  name=$2
  path=$3
  echo -e "  use_backend $name if !{ ssl_fc } { hdr(host) -i $domain } { path_beg $path }"
}

generate_link_ssl(){
  domain=$1
  name=$2
  path=$3
  echo -e "  use_backend $name if { ssl_fc_sni $domain } { path_beg $path }"
}

docker service ls --format='{{.Name}}' | while read service;do
  echo "Detected service '$service'"
  service_network=`docker service inspect $service --format='{{json .Spec.TaskTemplate.Networks}}' | jq -r '.[0].Aliases[0]'`

  domain=`read_label $service "frontal.domain"`
  path=`read_label $service "frontal.path" "/"`
  target_port=`read_label $service "frontal.target.port"`
  tls=`read_label $service "frontal.tls" "force"`

  if [[ "$domain" != "null" ]] || [[ "$target_port" != "null" ]];then

    mandatory $domain "frontal.domain"
    mandatory $target_port "frontal.target.port"

    echo "domain: $domain"
    echo "path: $path"
    echo "tls: $tls"
    echo "target_port: $target_port"

    if [[ "$tls" != "no" ]];then
      if ! cert_ok $domain;then
        issue_cert $domain $LE_EMAIL $LE_AGREE_TOS $LE_MODE
      fi
      add_cert $domain $CRT_LIST
    fi

    generate_backend $service_network $target_port $path >> $HAPROXY_CONFIG_BACKENDS

    case $tls in
      force)
        generate_ssl_redirect $domain >> $HAPROXY_CONFIG
        generate_link_ssl $domain $service_network $path >> $HAPROXY_CONFIG
      ;;
      yes)
        generate_link $domain $service_network $path >> $HAPROXY_CONFIG
        generate_link_ssl $domain $service_network $path >> $HAPROXY_CONFIG
      ;;
      no)
        generate_link $domain $service_network $path >> $HAPROXY_CONFIG
      ;;
      only)
        generate_link_ssl $domain $service_network $path >> $HAPROXY_CONFIG
      ;;
      *)
        throw_error "invalid option '$tls' for label frontal.tls" >&2
      ;;
    esac
  fi
done

haproxy -f $HAPROXY_CONFIG -f $HAPROXY_CONFIG_BACKENDS

sleep 300

