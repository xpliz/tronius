# 🚀 Kubernetes mTLS Demo with Kind & Ingress-NGINX

This repository contains scripts and Kubernetes manifests to **fully bootstrap a devops task** with:

- A **Kind cluster** named `tronius`, ready for ingress traffic on ports 80/443
- An **NGINX Ingress controller** installed automatically (if not already present)
- **Self signed TLS certificates** generated locally:
  - CA certificate
  - Server certificate for `myservice.example.com`
  - Client certificate for mTLS authentication
- **Kubernetes secrets** created for the client, server and CA certificates
- A **demo backend service** running HTTPS on port `8443`
- An **Ingress** routing HTTPS traffic from `myservice.example.com` to the backend with mTLS
- Automatic **waits** for kind cluster and ingress pods to be ready
- **mTLS script** to verify mTLS authentication
- A **curl test** at the end to verify the service is reachable using the CA certificate

This setup provides a **fully secured HTTPS environment with mTLS authentication** for testing and development on your local machine.

---

## 📦 Requirements

- [kind](https://kind.sigs.k8s.io/) — Kubernetes in Docker
- [kubectl](https://kubernetes.io/docs/tasks/tools/) — Kubernetes CLI
- [openssl](https://www.openssl.org/)

---

## ▶️ Usage

1. Clone the repository:

   ```bash
   git clone https://github.com/xpliz/tronius.git
   cd tronius
   ```

2. Generate certificates:

   ```bash
   ./generate-certs.sh
   ```

3. Bootstrap the Kind cluster and deploy everything:

   ```bash
   ./bootstrap.sh
   ```

---

## 🌐 Accessing the Service

1. Test the HTTPS endpoint:

   ```bash
   curl --cacert certs/ca/ca.crt.pem --resolve 'myservice.example.com:443:127.0.0.1' https://myservice.example.com
   ```

2. Verify certificate

   ```bash
   openssl s_client -CAfile certs/ca/ca.crt.pem -showcerts -connect localhost:443 -servername myservice.example.com </dev/null
   ```

### 🚀 You should see the demo HTML page served by the backend

### ⭐ For adding CA certificate to your OS, please refer to OS guide how to add self signed certificates

---

## 🔐 mTLS Testing

Test mTLS connection directly to backend

```bash
./test-mtls.sh
```

---

## 🗺 Architecture Diagram

```mermaid
flowchart LR
    Client[Client Browser / curl]
    Ingress[Ingress NGINX<br>Port 443]
    Backend[Backend Service<br>Port 8443]

    Client -->|HTTPS request| Ingress
    Ingress -->|mTLS/HTTPS| Backend
```

- **Client** connects via HTTPS to the Ingress controller (terminates TLS at ingress)
- **Ingress** presents a client certificate to authenticate with the **backend service** over mutual TLS (mTLS)
- **Backend service** requires and validates the client certificate from ingress, providing two-way authentication

---

## 🔒 mTLS Flow

1. Client to Ingress: Standard TLS - client verifies server certificate

2. Ingress to Backend: Mutual TLS (mTLS) - both parties authenticate each other
   - Backend presents its server certificate to ingress
   - Ingress presents its client certificate to backend
   - Both certificates are signed by the same trusted CA

---

## 🛠 Rerunning the Script

- Reuses cluster if it exists  
- Secrets are recreated silently  
- NGINX ingress only installs once  

---

## 🧹 Cleanup

```bash
kind delete cluster --name tronius
```
