# Blob Storage Kubernetes Deployment Guide

## Chart Overview

This Helm chart deploys a complete distributed blob storage system with the following components:

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Kubernetes Cluster                     │
│                                                               │
│  ┌──────────────┐         ┌──────────────┐                  │
│  │   Ingress    │────────▶│   Frontend   │                  │
│  │   (Optional) │         │  (LoadBalancer│                 │
│  └──────────────┘         │   or ClusterIP)                 │
│                           └──────┬───────┘                   │
│                                  │                            │
│                           ┌──────▼───────┐                   │
│                           │    Client    │                   │
│                           │     API      │                   │
│                           └──────┬───────┘                   │
│                                  │                            │
│                           ┌──────▼───────┐                   │
│                           │    Master    │                   │
│                           │    Server    │                   │
│                           └──────┬───────┘                   │
│                                  │                            │
│              ┌───────────────────┼───────────────────┐       │
│              │                   │                   │        │
│       ┌──────▼──────┐    ┌──────▼──────┐    ┌──────▼──────┐│
│       │ Chunkserver │    │ Chunkserver │    │ Chunkserver ││
│       │      0      │    │      1      │    │      2      ││
│       └─────────────┘    └─────────────┘    └─────────────┘│
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Components

1. **Master Server** (Deployment)
   - Manages metadata and chunk locations
   - Single replica (can be scaled with custom HA setup)
   - Persistent storage for operation logs
   - Port: 9100

2. **Chunk Servers** (StatefulSet)
   - Store actual data chunks
   - Default: 3 replicas (configurable)
   - Each has persistent storage
   - Port: 9900
   - Headless service for stable network identity

3. **Client API** (Deployment)
   - Provides programmatic access
   - Can be scaled horizontally
   - Port: 9000

4. **Frontend Web UI** (Deployment)
   - Web interface for file operations
   - Can be scaled horizontally
   - Supports LoadBalancer, NodePort, or Ingress
   - Port: 9400 (external), 8080 (container)

## Files Structure

```
helm/blob-storage/
├── Chart.yaml                          # Chart metadata
├── values.yaml                         # Default configuration values
├── values-dev.yaml                     # Development configuration
├── values-ingress.yaml                 # Ingress configuration example
├── .helmignore                         # Files to ignore in package
├── README.md                           # Full documentation
├── DEPLOYMENT_GUIDE.md                 # This file
└── templates/
    ├── _helpers.tpl                    # Template helper functions
    ├── NOTES.txt                       # Post-installation notes
    ├── master-deployment.yaml          # Master server deployment
    ├── master-service.yaml             # Master service
    ├── master-pvc.yaml                 # Master persistent volume
    ├── chunkserver-statefulset.yaml    # Chunk servers statefulset
    ├── chunkserver-service.yaml        # Chunk servers headless service
    ├── client-deployment.yaml          # Client API deployment
    ├── client-service.yaml             # Client service
    ├── frontend-deployment.yaml        # Frontend deployment
    ├── frontend-service.yaml           # Frontend service
    ├── frontend-pvc.yaml               # Frontend persistent volume
    └── frontend-ingress.yaml           # Frontend ingress (optional)
```

## Quick Deployment Scenarios

### 1. Local Development (Minikube/Kind)

```bash
# Install with minimal resources
helm install blob-storage ./blob-storage -f values-dev.yaml

# Access via port-forward
kubectl port-forward service/blob-storage-frontend 9400:9400
```

Features:
- 2 chunk servers instead of 3
- Reduced resource limits
- Smaller PVC sizes
- NodePort service type

### 2. Cloud Provider (AWS/GCP/Azure)

```bash
# Install with default values (uses LoadBalancer)
helm install blob-storage ./blob-storage

# Get LoadBalancer IP
kubectl get svc blob-storage-frontend
```

Features:
- 3 chunk servers
- LoadBalancer for frontend
- Larger PVC sizes
- Production-ready resources

### 3. Production with Ingress + SSL

```bash
# Ensure ingress controller is installed
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Install cert-manager for SSL
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create cluster issuer for Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Update values-ingress.yaml with your domain
# Then install
helm install blob-storage ./blob-storage -f values-ingress.yaml
```

Features:
- HTTPS with automatic SSL certificates
- Custom domain name
- Ingress-based routing
- Production resources

## Configuration Deep Dive

### Environment Variables

The chart configures services via environment variables based on docker-compose:

**Master Server:**
- `APP_ENV`: production/development
- `SERVER_HOST`: 0.0.0.0
- `SERVER_PORT`: 9100
- `CHUNK_SIZE`: 1048576 (1MB)
- `REPLICATION_FACTOR`: 3
- `OPLOG_PATH`: /app/data/master-oplog.jsonl
- `REBALANCE_INTERVAL`: 1m
- `REBALANCE_THRESHOLD`: 0.2
- `REBALANCE_MAX_MOVES`: 10

**Chunk Servers:**
- `APP_ENV`: production/development
- `SERVER_HOST`: 0.0.0.0
- `SERVER_PORT`: 9900
- `APP_HOST`: Auto-generated (pod-name.service.namespace.svc.cluster.local)
- `MASTER_URL`: Auto-generated from master service
- `UPLOADS_DIR`: /app/uploads

**Client API:**
- `APP_ENV`: production/development
- `SERVER_HOST`: 0.0.0.0
- `SERVER_PORT`: 9000
- `MASTER_URL`: Auto-generated from master service

**Frontend:**
- `APP_ENV`: production/development
- `SERVER_HOST`: 0.0.0.0
- `SERVER_PORT`: 9400
- `CLIENT_URL`: Auto-generated from client service
- `MASTER_URL`: Auto-generated from master service
- `UPLOADS_DIR`: /app/uploads

### Storage Configuration

**Master:**
- Default: 1Gi PVC
- AccessMode: ReadWriteOnce
- Stores operation logs

**Chunk Servers:**
- Default: 10Gi PVC per server
- AccessMode: ReadWriteOnce
- Stores actual chunk data
- Uses VolumeClaimTemplates in StatefulSet

**Frontend:**
- Default: 5Gi PVC
- AccessMode: ReadWriteOnce
- Temporary upload storage

### Service Discovery

Services communicate using Kubernetes DNS:

- Master: `blob-storage-master:9100`
- Client: `blob-storage-client:9000`
- Chunk Servers: `blob-storage-chunkserver-{0,1,2}.blob-storage-chunkserver:9900`

## Customization Examples

### Scale Chunk Servers to 5

```bash
helm upgrade blob-storage ./blob-storage --set chunkserver.replicaCount=5
```

### Use Custom Storage Class

```bash
helm upgrade blob-storage ./blob-storage \
  --set global.storageClass=fast-ssd
```

### Increase Master Resources

```yaml
# custom-values.yaml
master:
  resources:
    limits:
      cpu: 4000m
      memory: 4Gi
    requests:
      cpu: 1000m
      memory: 2Gi
```

```bash
helm upgrade blob-storage ./blob-storage -f custom-values.yaml
```

### Add Node Affinity for Chunk Servers

```yaml
# custom-values.yaml
chunkserver:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: storage-tier
            operator: In
            values:
            - high-performance
```

## Monitoring and Health Checks

All services expose `/health` endpoints:

- Liveness probes: Restart unhealthy containers
- Readiness probes: Remove from service endpoints when not ready
- Initial delay: 5s
- Period: 10s
- Timeout: 5s
- Failure threshold: 3

Check health manually:
```bash
kubectl exec blob-storage-master-xxx -- wget -O- http://localhost:9100/health
```

## Troubleshooting Common Issues

### 1. Pods Stuck in Pending

**Issue:** PVCs can't be bound

```bash
kubectl get pvc
kubectl describe pvc blob-storage-master
```

**Solution:** Install a storage provisioner or use existing storage class

### 2. Chunk Servers Not Registering with Master

**Issue:** Network connectivity or DNS issues

```bash
kubectl logs blob-storage-chunkserver-0
kubectl exec blob-storage-chunkserver-0 -- nslookup blob-storage-master
kubectl exec blob-storage-chunkserver-0 -- wget -O- http://blob-storage-master:9100/health
```

**Solution:** Check service and DNS configuration

### 3. Frontend Can't Connect to Client

**Issue:** Service misconfiguration

```bash
kubectl get svc blob-storage-client
kubectl logs blob-storage-frontend-xxx
```

**Solution:** Verify service names and ports

### 4. Ingress Not Working

**Issue:** Ingress controller not installed or misconfigured

```bash
kubectl get ingress
kubectl describe ingress blob-storage-frontend
kubectl get svc -n ingress-nginx
```

**Solution:** Install ingress controller and verify configuration

## Backup and Recovery

### Backup Master Metadata

```bash
# Create backup of master PVC
kubectl exec blob-storage-master-xxx -- tar czf /tmp/backup.tar.gz /app/data
kubectl cp blob-storage-master-xxx:/tmp/backup.tar.gz ./master-backup-$(date +%Y%m%d).tar.gz
```

### Restore Master Metadata

```bash
# Copy backup to pod
kubectl cp ./master-backup.tar.gz blob-storage-master-xxx:/tmp/
kubectl exec blob-storage-master-xxx -- tar xzf /tmp/backup.tar.gz -C /
kubectl rollout restart deployment blob-storage-master
```

## Production Checklist

- [ ] Configure persistent storage with appropriate storage class
- [ ] Set resource limits based on expected load
- [ ] Configure ingress with SSL/TLS
- [ ] Set up monitoring and alerting
- [ ] Configure backup strategy for master metadata
- [ ] Test disaster recovery procedures
- [ ] Configure pod disruption budgets for high availability
- [ ] Set up horizontal pod autoscaling (if needed)
- [ ] Configure network policies for security
- [ ] Review and adjust chunk server count based on data volume
- [ ] Set up logging aggregation
- [ ] Configure persistent volume snapshots

## Docker Images

The chart uses the following Docker images by default:

- `bartlomiejklimczak/blob-storage-master:latest`
- `bartlomiejklimczak/blob-storage-chunkserver:latest`
- `bartlomiejklimczak/blob-storage-client:latest`
- `bartlomiejklimczak/blob-storage-frontend-web:latest`

To use specific versions, override in values:

```yaml
master:
  image:
    tag: "v1.0.0"
```

## Support and Contributing

For issues or questions:
- Check the README.md for detailed configuration
- Review QUICKSTART.md for common scenarios
- Open an issue in the project repository

## License

See project repository for license information.
