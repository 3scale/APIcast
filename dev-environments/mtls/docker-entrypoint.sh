#!/bin/sh

#This entrypoint is responsible for leaving the OSCP running to accept requests
openssl ocsp -url http://0.0.0.0:2560 -text       -index /cert/index.txt       -CA /cert/ca-chain.cert.pem       -rkey /cert/ocsp.example.com.key.pem       -rsigner /cert/ocsp.example.com.cert.pem
