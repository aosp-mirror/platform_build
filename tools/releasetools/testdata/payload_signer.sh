#!/bin/sh

# The script will be called with 'payload_signer.sh <key> -in <input> -out <output>'.
openssl pkeyutl -sign -keyform DER -inkey $1 -pkeyopt digest:sha256 -in $3 -out $5
