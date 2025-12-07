# Blob Storage Helm Chart

A Helm chart for deploying a distributed blob storage filesystem on Kubernetes, featuring master server, chunk servers, client API, and web frontend.

## Overview

This chart deploys a complete distributed filesystem with the following components:

- **Master Server**: Manages file metadata and chunk locations
- **Chunk Servers**: Store the actual data chunks (StatefulSet with persistent storage)
- **Client API**: Provides programmatic access to the filesystem
- **Frontend Web UI**: Web interface for file operations

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- PV provisioner support in the underlying infrastructure (for persistent storage)

## Installation

### Add the repository (if published)

```bash
helm repo add blob-storage <repository-url>
helm repo update
```

### Install from local chart

```bash
# From the helm directory
helm install my-blob-storage ./blob-storage

# Or with custom values
helm install my-blob-storage ./blob-storage -f custom-values.yaml
```

### Install with custom namespace

```bash
kubectl create namespace blob-storage
helm install my-blob-storage ./blob-storage --namespace blob-storage
```

## Configuration

The following table lists the configurable parameters and their default values.

### Global Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.imageRegistry` | Global Docker image registry | `""` |
| `global.imagePullSecrets` | Global Docker registry secrets | `[]` |
| `global.storageClass` | Global storage class for PVCs | `""` |
| `global.appVersion` | Global app version for all images | `"latest"` |

### Master Server Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `master.enabled` | Enable master server | `true` |
| `master.replicaCount` | Number of replicas | `1` |
| `master.image.registry` | Image registry | `docker.io` |
| `master.image.repository` | Image repository | `bartlomiejklimczak/blob-storage-master` |
| `master.image.tag` | Image tag | `latest` |
| `master.service.type` | Service type | `ClusterIP` |
| `master.service.port` | Service port | `9100` |
| `master.persistence.enabled` | Enable persistence | `true` |
| `master.persistence.size` | PVC size | `1Gi` |
| `master.resources.limits.cpu` | CPU limit | `1000m` |
| `master.resources.limits.memory` | Memory limit | `512Mi` |

### Chunk Server Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `chunkserver.enabled` | Enable chunk servers | `true` |
| `chunkserver.replicaCount` | Number of chunk servers | `3` |
| `chunkserver.image.repository` | Image repository | `bartlomiejklimczak/blob-storage-chunkserver` |
| `chunkserver.service.type` | Service type | `ClusterIP` |
| `chunkserver.service.port` | Service port | `9900` |
| `chunkserver.persistence.enabled` | Enable persistence | `true` |
| `chunkserver.persistence.size` | PVC size per server | `10Gi` |
| `chunkserver.resources.limits.cpu` | CPU limit | `1000m` |
| `chunkserver.resources.limits.memory` | Memory limit | `1Gi` |

### Client API Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `client.enabled` | Enable client API | `true` |
| `client.replicaCount` | Number of replicas | `1` |
| `client.image.repository` | Image repository | `bartlomiejklimczak/blob-storage-client` |
| `client.service.type` | Service type | `ClusterIP` |
| `client.service.port` | Service port | `9000` |
| `client.resources.limits.cpu` | CPU limit | `1000m` |
| `client.resources.limits.memory` | Memory limit | `512Mi` |

### Frontend Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `frontend.enabled` | Enable frontend | `true` |
| `frontend.replicaCount` | Number of replicas | `1` |
| `frontend.image.repository` | Image repository | `bartlomiejklimczak/blob-storage-frontend-web` |
| `frontend.service.type` | Service type | `LoadBalancer` |
| `frontend.service.port` | Service port | `9400` |
| `frontend.ingress.enabled` | Enable ingress | `false` |
| `frontend.ingress.className` | Ingress class name | `""` |
| `frontend.ingress.annotations` | Ingress annotations | `{}` |
| `frontend.ingress.hosts` | Ingress hosts configuration | See values.yaml |
| `frontend.ingress.tls` | Ingress TLS configuration | `[]` |
| `frontend.persistence.enabled` | Enable persistence | `true` |
| `frontend.persistence.size` | PVC size | `5Gi` |
| `frontend.resources.limits.cpu` | CPU limit | `500m` |
| `frontend.resources.limits.memory` | Memory limit | `256Mi` |

## Example Configurations

### Minimal Installation (for development)

```yaml
# values-dev.yaml
master:
  persistence:
    size: 100Mi
  resources:
    limits:
      cpu: 500m
      memory: 256Mi
    requests:
      cpu: 50m
      memory: 64Mi

chunkserver:
  replicaCount: 2
  persistence:
    size: 1Gi
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 128Mi

frontend:
  service:
    type: NodePort
```

Install:
```bash
helm install my-blob-storage ./blob-storage -f values-dev.yaml
```

### Production Configuration

```yaml
# values-prod.yaml
global:
  storageClass: "fast-ssd"

master:
  replicaCount: 1
  persistence:
    size: 10Gi
  resources:
    limits:
      cpu: 2000m
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 512Mi

chunkserver:
  replicaCount: 5
  persistence:
    size: 100Gi
  resources:
    limits:
      cpu: 2000m
      memory: 4Gi
    requests:
      cpu: 500m
      memory: 1Gi
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app.kubernetes.io/component
              operator: In
              values:
              - chunkserver
          topologyKey: kubernetes.io/hostname

client:
  replicaCount: 2
  resources:
    limits:
      cpu: 2000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi

frontend:
  replicaCount: 2
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
  resources:
    limits:
      cpu: 1000m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi
```

Install:
```bash
helm install my-blob-storage ./blob-storage -f values-prod.yaml
```

### Using Private Docker Registry

```yaml
# values-private.yaml
global:
  imageRegistry: "my-registry.example.com"
  imagePullSecrets:
    - name: my-registry-secret
  appVersion: "v1.0.0"  # Set version for all images

master:
  image:
    repository: my-org/blob-storage-master

chunkserver:
  image:
    repository: my-org/blob-storage-chunkserver

client:
  image:
    repository: my-org/blob-storage-client

frontend:
  image:
    repository: my-org/blob-storage-frontend-web

# You can also override individual image tags:
# master:
#   image:
#     tag: "v1.0.1"
```

First, create the image pull secret:
```bash
kubectl create secret docker-registry my-registry-secret \
  --docker-server=my-registry.example.com \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email>
```

Then install:
```bash
helm install my-blob-storage ./blob-storage -f values-private.yaml
```

### Using Ingress (Recommended for Production)

```yaml
# values-ingress.yaml
frontend:
  service:
    type: ClusterIP  # Change from LoadBalancer when using Ingress
    port: 9400

  ingress:
    enabled: true
    className: "nginx"
    annotations:
      nginx.ingress.kubernetes.io/proxy-body-size: "100m"
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
      # For SSL with cert-manager
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
    hosts:
      - host: blob-storage.yourdomain.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: blob-storage-tls
        hosts:
          - blob-storage.yourdomain.com
```

Prerequisites for Ingress:
```bash
# Install NGINX Ingress Controller (if not already installed)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Install cert-manager for SSL (optional)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

Install with Ingress:
```bash
helm install my-blob-storage ./blob-storage -f values-ingress.yaml
```

Access via your domain:
```bash
# After DNS is configured
https://blob-storage.yourdomain.com
```

## Accessing the Application

### Via LoadBalancer (default for frontend)

```bash
export SERVICE_IP=$(kubectl get svc --namespace default blob-storage-frontend --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
echo "Frontend URL: http://$SERVICE_IP:9400"
```

### Via Port Forward

```bash
# Frontend
kubectl port-forward service/blob-storage-frontend 9400:9400

# Client API
kubectl port-forward service/blob-storage-client 9000:9000

# Master
kubectl port-forward service/blob-storage-master 9100:9100
```

## Scaling

### Scale Chunk Servers

```bash
# Scale to 5 chunk servers
helm upgrade my-blob-storage ./blob-storage --set chunkserver.replicaCount=5

# Or using kubectl
kubectl scale statefulset my-blob-storage-chunkserver --replicas=5
```

### Scale Client API

```bash
helm upgrade my-blob-storage ./blob-storage --set client.replicaCount=3
```

## Monitoring

The services expose health check endpoints:

- Master: `http://<master-service>:9100/health`
- Chunk Servers: `http://<chunkserver-pod>:9900/health`
- Client API: `http://<client-service>:9000/health`
- Frontend: `http://<frontend-service>:8080/health`

Check pod health:
```bash
kubectl get pods -l "app.kubernetes.io/instance=my-blob-storage"
```

## Troubleshooting

### Check logs

```bash
# All components
kubectl logs -l "app.kubernetes.io/instance=my-blob-storage" --all-containers=true

# Master only
kubectl logs -l "app.kubernetes.io/component=master"

# Chunk servers
kubectl logs -l "app.kubernetes.io/component=chunkserver"

# Specific chunk server
kubectl logs my-blob-storage-chunkserver-0
```

### Check storage

```bash
# List persistent volume claims
kubectl get pvc -l "app.kubernetes.io/instance=my-blob-storage"

# Check volume usage
kubectl exec my-blob-storage-chunkserver-0 -- df -h /app/uploads
```

### Restart services

```bash
# Restart master
kubectl rollout restart deployment my-blob-storage-master

# Restart chunk servers (one at a time)
kubectl delete pod my-blob-storage-chunkserver-0
```

## Upgrading

```bash
helm upgrade my-blob-storage ./blob-storage
```

With new values:
```bash
helm upgrade my-blob-storage ./blob-storage -f values-prod.yaml
```

## Uninstalling

```bash
helm uninstall my-blob-storage
```

Note: This will not delete PVCs by default. To delete them:
```bash
kubectl delete pvc -l "app.kubernetes.io/instance=my-blob-storage"
```

## License

See the project repository for license information.
