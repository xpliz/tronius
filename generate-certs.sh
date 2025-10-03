#!/usr/bin/env bash
set -euo pipefail

DOMAIN="myservice.example.com"
ORGANIZATION="Tronius"

WORKDIR="./certs"
mkdir -p "$WORKDIR/ca" "$WORKDIR/server" "$WORKDIR/client"

echo "⭐ Create CA key and self-signed cert"
openssl genrsa -out "$WORKDIR/ca/ca.key.pem" 4096
openssl req -x509 -new -nodes -key "$WORKDIR/ca/ca.key.pem" -sha256 -days 3650 -out "$WORKDIR/ca/ca.crt.pem" -subj "/CN=Demo/O=${ORGANIZATION}"

echo "🚀 Create server key and CSR"
openssl genrsa -out "$WORKDIR/server/server.key.pem" 2048
cat > "$WORKDIR/server/server.cnf" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
[req_distinguished_name]
[ v3_req ]
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = ${DOMAIN}
EOF

openssl req -new -key "$WORKDIR/server/server.key.pem" -out "$WORKDIR/server/server.csr.pem" -subj "/CN=${DOMAIN}/O=${ORGANIZATION}" -config "$WORKDIR/server/server.cnf"

echo "🔏 Sign server CSR with CA (server cert includes SAN)"
openssl x509 -req -in "$WORKDIR/server/server.csr.pem" -CA "$WORKDIR/ca/ca.crt.pem" -CAkey "$WORKDIR/ca/ca.key.pem" -CAcreateserial -out "$WORKDIR/server/server.crt.pem" -days 365 -sha256 -extensions v3_req -extfile "$WORKDIR/server/server.cnf"

echo "🔑 Create client key and CSR for ingress"
openssl genrsa -out "$WORKDIR/client/client.key.pem" 2048
openssl req -new -key "$WORKDIR/client/client.key.pem" -out "$WORKDIR/client/client.csr.pem" -subj "/CN=ingress-client/O=${ORGANIZATION}"

echo "📜 Sign client CSR with CA"
openssl x509 -req -in "$WORKDIR/client/client.csr.pem" -CA "$WORKDIR/ca/ca.crt.pem" -CAkey "$WORKDIR/ca/ca.key.pem" -CAcreateserial -out "$WORKDIR/client/client.crt.pem" -days 365 -sha256

# Verify the certificates
echo "🔍 Verifying certificates..."
openssl verify -CAfile "$WORKDIR/ca/ca.crt.pem" "$WORKDIR/server/server.crt.pem"
openssl verify -CAfile "$WORKDIR/ca/ca.crt.pem" "$WORKDIR/client/client.crt.pem"

ls -l "$WORKDIR"/**/*.pem

echo "✅ Done. Certs are in $WORKDIR"
