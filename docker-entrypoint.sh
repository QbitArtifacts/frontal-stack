#!/usr/bin/env bash

if ! test -f /etc/ssl;then
  mkdir -p /etc/ssl
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
  cat fullchain.pem privkey.pem > /etc/ssl/$domain.pem
  echo "/etc/ssl/$domain.pem" >> $list_file
  cd -
}

generate_backend(){
  name=$1
  port=$2
  echo -e "backend $name"
  echo -e "\tserver $name $name:$port check"
}

generate_ssl_redirect(){
  domain=$1
  echo -e "redirect scheme https if !{ ssl_fc} { hdr(host) -i $domain }"
}

generate_link(){
  domain=$1
  name=$2
  echo -e "use_backend $name if !{ ssl_fc } { hdr(host) -i $domain }"
}

generate_link_ssl(){
  domain=$1
  name=$2
  echo -e "use_backend $name if { ssl_fc_sni $domain }"
}

docker service ls --format='{{.Name}}' | while read service;do
  echo "Detected service '$service'"

  domain=`read_label $service "frontal.domain"`
  path=`read_label $service "frontal.path" "/"`
  target_port=`read_label $service "frontal.target.port"`
  tls=`read_label $service "frontal.tls" "force"`

  if [[ "$domain" != "null" ]] || [[ "$target_port" != "null" ]];then

    mandatory $domain "frontal.domain"
    mandatory $target_port "frontal.target.port"

    echo $domain
    echo $path
    echo $tls
    echo $https_port
    echo $http_port
    echo $target_port

    if [[ "$tls" != "no" ]];then
      if ! cert_ok $domain;then
        issue_cert $domain $LE_EMAIL $LE_AGREE_TOS $LE_MODE
      fi
      add_cert $domain /etc/ssl/crt-list.txt
    fi

    generate_backend $service_name $target_port >> /etc/haproxy/backends.cfg

    case $tls in
      force)
        generate_ssl_redirect $domain >> /etc/haproxy/redirects.cfg
        generate_link_ssl $domain $service_name >> /etc/haproxy/bindings.cfg
      ;;
      yes)
        generate_link $domain $service_name >> /etc/haproxy/bindings.cfg
        generate_link_ssl $domain $service_name >> /etc/haproxy/bindings.cfg
      ;;
      no)
        generate_link $domain $service_name >> /etc/haproxy/bindings.cfg
      ;;
      only)
        generate_link_ssl $domain $service_name >> /etc/haproxy/bindings.cfg
      ;;
      *)
        throw_error "invalid option '$tls' for label frontal.tls" >&2
      ;;
    esac
    #target_host=`cut -d_ -f2 <<<$service` # TODO: find the host value from service
  fi
done


haproxy haproxy -f /etc/haproxy/base.cfg -f /etc/haproxy/redirects.cfg -f /etc/haproxy/backends.cfg -f /etc/haproxy/bindings.cfg

# docker service inspect rec-stage_frontal --format='{{json .Spec.TaskTemplate.Networks}}' | jq -r '.[0].Target'
