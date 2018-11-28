#!/bin/bash

#
# Entrypoint for HAProxy
#
# We assume having the letsencrypt certificates up-to-date and a service named "letsencrypt" with port 80 open to redirect domain renewals
# We need the $BINDINGS env var defined like this:
#   BINDINGS="(example.com,www.example.com)=stage-letsencrypt:80"
#

export LETSENCRYPT_DIR=/etc/letsencrypt/live
export SSL_DIR=/etc/ssl
export CERTS_DIR=$SSL_DIR/certs
export CRT_LIST_FILE=$SSL_DIR/crt-list.txt

cd $LETSENCRYPT_DIR


if ! test -d $CERTS_DIR;then
    mkdir -p $CERTS_DIR
fi

echo -n > $CRT_LIST_FILE

for domain in *;do
    cd $domain
    cat fullchain.pem privkey.pem > $CERTS_DIR/$domain.pem
    echo "$CERTS_DIR/$domain.pem" >> $CRT_LIST_FILE
    cd ..
done

cd /

USE_BACKEND_TMP=/tmp/$RANDOM$RANDOM
BACKEND_TMP=/tmp/$RANDOM$RANDOM
echo -n > $USE_BACKEND_TMP
echo -n > $BACKEND_TMP

echo -e "backend letsencrypt" >> $BACKEND_TMP
echo -e "\tserver letsencrypt letsencrypt:80" >> $BACKEND_TMP
echo >> $BACKEND_TMP

for((i=1;;i++));do
    bind=`cut -d, -f$i <<<$BINDINGS`
    if [[ "$bind" != "" ]];then
        domains=`cut -d= -f1 <<<$bind | sed 's/[()]//g'`
        server=`cut -d= -f2 <<<$bind`
        backend_hash=`md5sum <<<$server | cut -d" " -f1`
        server_hash=$backend_hash
        for((i=1;;i++));do
            domain=`cut -d"|" -f$i <<<$domains`
            if [[ "$domain" != "" ]];then
                echo -e "\tuse_backend $backend_hash if { ssl_fc_sni $domain }" >> $USE_BACKEND_TMP
            else break
            fi
        done

        echo -e "backend $backend_hash" >> $BACKEND_TMP
        echo -e "\tserver $server_hash $server check" >> $BACKEND_TMP
        echo >> $BACKEND_TMP
    else break
    fi
done

HAPROXY_CONF=/usr/local/etc/haproxy/haproxy.cfg
cat $USE_BACKEND_TMP >> $HAPROXY_CONF
echo >> $HAPROXY_CONF
cat $BACKEND_TMP >> $HAPROXY_CONF

rm $USE_BACKEND_TMP $BACKEND_TMP

./docker-entrypoint.sh haproxy -f $HAPROXY_CONF

