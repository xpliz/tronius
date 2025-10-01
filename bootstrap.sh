#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="tronius"

echo "🚀 Creating Kind cluster '$CLUSTER_NAME'..."

# Check if cluster already exists
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "⚠️ Cluster '$CLUSTER_NAME' already exists. Skipping creation..."
else
  echo "🚀 Creating Kind cluster '$CLUSTER_NAME'..."
  cat <<EOF | kind create cluster --name "$CLUSTER_NAME" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
fi

# Wait for the control-plane node to be ready
echo "⏳ Waiting for Kind control-plane node to be ready..."
kubectl wait --for=condition=Ready node/"$CLUSTER_NAME"-control-plane --timeout=120s

if kubectl get deployment ingress-nginx-controller -n ingress-nginx >/dev/null 2>&1; then
  echo "⚠️ NGINX Ingress controller already installed. Skipping..."
else
  echo "📦 Installing NGINX Ingress controller..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
fi

# Wait for ingress controller pods to be ready
echo "⏳ Waiting for Ingress NGINX pods to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

echo "🌐 Ingress controller is ready. You can access your service at https://myservice.example.com (or 127.0.0.1 if using /etc/hosts)."

# Create TLS secret for backend
echo "🔐 Creating server TLS secret..."
kubectl delete secret myservice-cert -n default &>/dev/null || true
kubectl create secret tls myservice-cert \
  --cert=certs/server/server.crt.pem \
  --key=certs/server/server.key.pem \
  -n default

# CA secret for verification (if needed)
kubectl delete secret myservice-ca -n default &>/dev/null || true
kubectl create secret generic myservice-ca \
  --from-file=ca.crt=certs/ca/ca.crt.pem -n default

# Deploy backend
echo "🚀 Deploying backend..."
kubectl apply -f manifests/backend.yaml

# Wait for backend pods to be ready
echo "⏳ Waiting for backend pod to be ready..."
kubectl wait --for=condition=Ready pod -l app=myservice --timeout=120s

# Deploy ingress
echo "🚀 Deploying Ingress..."
kubectl apply -f manifests/ingress.yaml

# Wait for ingress service to be available
echo "⏳ Waiting services to settle ..."
# timeout=60
# while [[ $timeout -gt 0 ]]; do
#   ip=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
#   if [[ -n "$ip" ]]; then
#     echo "Ingress is available at $ip"
#     break
#   fi
#   sleep 2
#   timeout=$((timeout - 2))
# done
sleep 5

echo "🌐 Testing backend service at https://myservice.example.com/ ..."

echo
curl -sv --cacert certs/ca/ca.crt.pem https://myservice.example.com/ || \
  echo "❌ Could not reach the service. Make sure your DNS/hosts entry points to Kind cluster."
echo
echo

echo "✅ Kind cluster bootstrapped successfully with backend and ingress!"
