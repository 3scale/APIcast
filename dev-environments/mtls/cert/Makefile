DOMAIN=example.com

clean:
	- rm *.crt *.key *.pem *.csr index.* crlnumber crlnumber.* serial serial.* *.srl

all: index ca intermediate ca-chain ocsp server client revoked_client crl client-chain revoked-client-chain

index:
	touch index.txt
	echo 1000 > serial
	echo 1000 > crlnumber

ca:
	openssl genrsa -out rootCA.key.pem 2048
	openssl req -config root-ca.cnf \
	  -key rootCA.key.pem \
	  -new -x509 -days 3650 -sha256 -extensions v3_ca \
      -out rootCA.cert.pem \
	  -subj "/C=US/CN=ca.$(DOMAIN)"

intermediate:
	openssl genrsa -out intermediate.key.pem 2048
	openssl req -config intermediate.cnf \
      -key intermediate.key.pem \
      -new -sha256 \
      -out intermediate.csr.pem \
      -subj "/CN=intermediate-cert.$(DOMAIN)"
	openssl ca -config root-ca.cnf \
      -extensions v3_intermediate_ca -days 2650 -notext -batch \
      -in intermediate.csr.pem \
      -out intermediate.cert.pem

ca-chain:
	cat intermediate.cert.pem rootCA.cert.pem > ca-chain.cert.pem

crl:
	openssl ca -config intermediate.cnf \
	  -gencrl -out intermediate.crl.pem

ocsp:
	openssl genrsa -out ocsp.$(DOMAIN).key.pem 2048
	openssl req -config intermediate.cnf -new -sha256 \
      -key ocsp.$(DOMAIN).key.pem \
      -out ocsp.$(DOMAIN).csr.pem \
      -nodes \
      -subj "/CN=ocsp.$(DOMAIN)"
	openssl ca -config intermediate.cnf \
	  -extensions v3_ocsp -days 2650 -notext -batch \
	  -in ocsp.$(DOMAIN).csr.pem \
	  -out ocsp.$(DOMAIN).cert.pem

server:
	openssl req -subj '/CN=$(DOMAIN)'  -newkey rsa:4096 -nodes \
			-sha256 \
			-days 3650 \
			-keyout $(DOMAIN).key \
			-out $(DOMAIN).csr
	chmod +r $(DOMAIN).key
	openssl x509 -req -in $(DOMAIN).csr -CA rootCA.cert.pem -CAkey rootCA.key.pem -CAcreateserial -out $(DOMAIN).crt -days 500 -sha256
	openssl ca -config root-ca.cnf \
	  -extensions v3_intermediate_ca -days 2650 -notext -batch \
	  -in $(DOMAIN).csr \
	  -out $(DOMAIN).pem

client:
	openssl genrsa -out client.key.pem 2048
	openssl req -config intermediate.cnf -new -sha256 \
		  -key client.key.pem \
		  -out client.csr.pem \
		  -nodes \
		  -subj "/CN=client-cert.$(DOMAIN)"
	echo -e "y\ny\n" | openssl ca -config intermediate.cnf \
		  -extensions v3_leaf -days 375 -notext -md sha256 \
		  -in client.csr.pem \
		  -out client.cert.pem

revoked_client:
	openssl genrsa -out revoked_client.key.pem 2048
	openssl req -config intermediate.cnf -new -sha256 \
		  -key revoked_client.key.pem \
		  -out revoked_client.csr.pem \
		  -nodes \
		  -subj "/CN=revoked_client-cert.$(DOMAIN)"
	echo -e "y\ny\n" | openssl ca -config intermediate.cnf \
		  -extensions v3_leaf -days 375 -notext -md sha256 \
		  -in revoked_client.csr.pem \
		  -out revoked_client.cert.pem
	openssl ca -config intermediate.cnf -revoke revoked_client.cert.pem

client-chain:
	cat client.cert.pem intermediate.cert.pem > client-chain.cert.pem

revoked-client-chain:
	cat revoked_client.cert.pem intermediate.cert.pem > revoked_client-chain.cert.pem
