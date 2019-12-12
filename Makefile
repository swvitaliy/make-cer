
DOMAIN ?= mydomain.com

COUNTRY := RU
STATE := RU
COMPANY := Internet Widgits Pty Ltd 
IP := 

HOST := $(or $(HOST), $(IP), $(DOMAIN))
PORT := 443

# credits to: https://gist.github.com/fntlnz/cf14feb5a46b2eda428e000157447309

# usage:
# make rootCA.crt # (rootCA.key implicitly created)
# mkdir somedomain.dev
# 
# make DOMAIN=somedomain.dev somedomain.dev.csr somedomain.dev.crt   or   make DOMAIN=somedomain.dev
#
# OR WITH IP Adress:
# make DOMAIN=somedomain.dev IP=1.2.3.4 somedomain.dev.csr somedomain.dev.crt   or   make DOMAIN=somedomain.dev IP=1.2.3.4
# make DOMAIN=somedomain.dev verify-csr
# make DOMAIN=somedomain.dev verify-crt

# import rootCA.crt to the client (chrome)
# upload somedomain.dev.crt   and   somedomain.dev.key   to the host

all: $(DOMAIN).csr $(DOMAIN).crt $(DOMAIN).pfx


rootCA.key:
	openssl genrsa -out rootCA.key 4096

# create and self sign root certificate
rootCA.crt: rootCA.key
	echo "$(COUNTRY)\n$(STATE)\n\n$(COMPANY)\n\n\n\n" | openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1024 -out $@

$(DOMAIN).key:
	openssl genrsa -out $(DOMAIN)/server.key 2048

$(DOMAIN).conf:
	sh mkconf.sh $(DOMAIN) $(IP) >$(DOMAIN)/config.conf

$(DOMAIN).csr: $(DOMAIN).key $(DOMAIN).conf
	openssl req -new -sha256 -key $(DOMAIN)/server.key -subj "/C=$(COUNTRY)/ST=$(STATE)/O=$(COMPANY)/CN=$(DOMAIN)" \
		-reqexts SAN \
		-config $(DOMAIN)/config.conf \
		-out $(DOMAIN)/server.csr

# verify .csr content
.PHONY: verify-csr
verify-csr:
	openssl req  -in $(DOMAIN)/server.csr -noout -text

$(DOMAIN).san.conf:
	sh mksan.sh $(DOMAIN) $(COUNTRY) $(STATE) "$(COMPANY)" "$(IP)" >$(DOMAIN)/config.san.conf

$(DOMAIN).crt: rootCA.key rootCA.crt $(DOMAIN).csr $(DOMAIN).san.conf
	openssl x509 -req -in $(DOMAIN)/server.csr -CA ./rootCA.crt -CAkey ./rootCA.key \
		-CAcreateserial -out $(DOMAIN)/server.crt -days 500 -sha256 \
		-extfile $(DOMAIN)/config.san.conf -extensions req_ext

$(DOMAIN).pfx: $(DOMAIN).crt
	openssl pkcs12 -export -out $(DOMAIN)/server.pfx -inkey $(DOMAIN)/server.key -in $(DOMAIN)/server.crt

# verify the certificate
.PHONY: verify-crt
verify-crt:
	openssl x509 -in $(DOMAIN)/server.crt -text -noout

.PHONY: fingerprint-crt
fingerprint-crt:
	openssl x509 -in $(DOMAIN)/server.crt -noout -fingerprint -sha256

.PHONY: show-remote-crt
show-remote-crt:
	openssl s_client -showcerts -connect $(HOST):$(PORT) 2>/dev/null  | openssl x509 -inform pem -noout -text

.PHONY: clean
clean:
	-rm -f $(DOMAIN)/server.key $(DOMAIN)/server.csr $(DOMAIN)/config.conf $(DOMAIN)/config.san.conf $(DOMAIN)/server.crt $(DOMAIN)/server.pfx
