#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Testing mTLS connection directly to backend..."

# Port-forward to the backend service
kubectl port-forward svc/myservice 8443:8443 &
PORT_FORWARD_PID=$!

# Wait for port-forward to be established
sleep 3
echo

echo "🔹 Testing without any certificate (should fail):"
curl -k --resolve 'myservice.example.com:8443:127.0.0.1' \
     https://myservice.example.com:8443/

echo
echo "🔹 Testing with CA certificate (should fail):"
curl --cacert certs/ca/ca.crt.pem \
     --resolve 'myservice.example.com:8443:127.0.0.1' \
     https://myservice.example.com:8443/

echo
echo "🔹 Testing with client certificate (should succeed):"
curl --cacert certs/ca/ca.crt.pem \
     --cert certs/client/client.crt.pem \
     --key certs/client/client.key.pem \
     --resolve 'myservice.example.com:8443:127.0.0.1' \
     https://myservice.example.com:8443/

# Kill port-forward
kill $PORT_FORWARD_PID

echo
echo "✅ mTLS test completed"
