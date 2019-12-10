#!/bin/sh

IP=$2

if [ "${IP}" != "" ];
then

cat <<EOF
$(cat /etc/ssl/openssl.cnf)

[SAN]
subjectAltName=IP:${IP}
EOF

else

cat <<EOF
$(cat /etc/ssl/openssl.cnf)

[SAN]
subjectAltName=DNS:$1,DNS:www.$1
EOF

fi
