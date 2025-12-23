# Deployment Guide

Complete guide for deploying the Go Microservices Platform to various environments.

## Table of Contents

- [Deployment Overview](#deployment-overview)
- [Local Development (Docker Compose)](#local-development-docker-compose)
- [Production Deployment (Kubernetes)](#production-deployment-kubernetes)
- [Cloud Providers](#cloud-providers)
- [CI/CD Pipeline](#cicd-pipeline)
- [Security Considerations](#security-considerations)
- [Monitoring & Logging](#monitoring--logging)
- [Backup & Recovery](#backup--recovery)

---

## Deployment Overview

### Supported Deployment Options

| Environment | Technology | Use Case | Complexity |
|-------------|------------|----------|------------|
| **Local Dev** | Docker Compose | Development, testing | Low |
| **Kubernetes** | K8s + kubectl | Production, staging | Medium |
| **AWS ECS** | Fargate/ECS | AWS-native deployment | Medium |
| **GCP GKE** | Google Kubernetes Engine | GCP deployment | Medium |
| **Azure AKS** | Azure Kubernetes Service | Azure deployment | Medium |

---

## Local Development (Docker Compose)

### Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- 4GB RAM minimum
- 10GB free disk space

### Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/go-microservices-platform.git
cd go-microservices-platform

# Start all services
docker-compose up --build -d

# Verify all services are running
docker-compose ps

# View logs
docker-compose logs -f

# Stop all services
docker-compose down

# Stop and remove volumes (clean slate)
docker-compose down -v
```

### Service Ports

| Service | Port | Access |
|---------|------|--------|
| Broker | 8080 | http://localhost:8080 |
| Frontend | 8081 | http://localhost:8081 |
| PostgreSQL | 5432 | localhost:5432 |
| MongoDB | 27017 | localhost:27017 |
| RabbitMQ | 5672 | localhost:5672 |
| RabbitMQ Management | 15672 | http://localhost:15672 |
| MailHog Web | 8025 | http://localhost:8025 |

### Docker Compose Configuration

```yaml
version: '3.9'

services:
  broker-service:
    build:
      context: ./broker-service
      dockerfile: Dockerfile
    restart: always
    ports:
      - "8080:80"
    environment:
      RABBIT_URL: "amqp://guest:guest@rabbitmq:5672/"
      GRPC_URL: "logger-service:5001"
    depends_on:
      - postgres
      - mongo
      - rabbitmq
    deploy:
      mode: replicated
      replicas: 1
```

### Building Individual Services

```bash
# Build specific service
docker-compose build broker-service

# Build without cache
docker-compose build --no-cache authentication-service

# Pull latest base images
docker-compose pull
```

### Troubleshooting Docker Compose

**Issue**: Services not starting
```bash
# Check service status
docker-compose ps

# View specific service logs
docker-compose logs broker-service

# Restart specific service
docker-compose restart broker-service
```

**Issue**: Port conflicts
```bash
# Change ports in docker-compose.yml
ports:
  - "8081:80"  # Change 8081 to available port
```

**Issue**: Database connection errors
```bash
# Verify database is ready
docker-compose exec postgres psql -U postgres -c "SELECT 1;"

# Check MongoDB
docker-compose exec mongo mongosh --eval "db.runCommand({ ping: 1 })"
```

---

## Production Deployment (Kubernetes)

### Prerequisites

- Kubernetes cluster (v1.24+)
- kubectl configured
- Container registry (Docker Hub, GCR, ECR)
- 8GB RAM minimum across nodes
- Persistent storage provider

### Step 1: Build and Push Docker Images

```bash
# Set your registry
REGISTRY="yourusername"
VERSION="v1.0.0"

# Build images
docker build -t $REGISTRY/broker-service:$VERSION ./broker-service
docker build -t $REGISTRY/auth-service:$VERSION ./authentication-service
docker build -t $REGISTRY/logger-service:$VERSION ./logger-service
docker build -t $REGISTRY/mail-service:$VERSION ./mail-service
docker build -t $REGISTRY/listener-service:$VERSION ./listener-service

# Push to registry
docker push $REGISTRY/broker-service:$VERSION
docker push $REGISTRY/auth-service:$VERSION
docker push $REGISTRY/logger-service:$VERSION
docker push $REGISTRY/mail-service:$VERSION
docker push $REGISTRY/listener-service:$VERSION

# Tag as latest
docker tag $REGISTRY/broker-service:$VERSION $REGISTRY/broker-service:latest
docker push $REGISTRY/broker-service:latest
```

### Step 2: Create Kubernetes Namespace

```bash
# Create namespace
kubectl create namespace microservices

# Set as default namespace
kubectl config set-context --current --namespace=microservices
```

### Step 3: Configure Secrets

```bash
# Create database credentials secret
kubectl create secret generic db-credentials \
  --from-literal=postgres-user=postgres \
  --from-literal=postgres-password=your-secure-password \
  --from-literal=mongo-user=admin \
  --from-literal=mongo-password=your-secure-password

# Create SMTP credentials
kubectl create secret generic smtp-credentials \
  --from-literal=smtp-host=smtp.gmail.com \
  --from-literal=smtp-port=587 \
  --from-literal=smtp-user=your-email@gmail.com \
  --from-literal=smtp-password=your-app-password

# Create RabbitMQ credentials
kubectl create secret generic rabbitmq-credentials \
  --from-literal=username=admin \
  --from-literal=password=your-secure-password
```

### Step 4: Create ConfigMaps

```bash
# Create application config
kubectl create configmap app-config \
  --from-literal=broker-url=http://broker-service \
  --from-literal=auth-url=http://authentication-service \
  --from-literal=logger-url=http://logger-service \
  --from-literal=mail-url=http://mail-service
```

### Step 5: Deploy Infrastructure Components

#### PostgreSQL Deployment

```yaml
# k8s/postgres-deployment.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:14-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: postgres-user
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: postgres-password
        - name: POSTGRES_DB
          value: users
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
  type: ClusterIP
```

```bash
kubectl apply -f k8s/postgres-deployment.yaml
```

#### MongoDB Deployment

```yaml
# k8s/mongo-deployment.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongo-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongo
  template:
    metadata:
      labels:
        app: mongo
    spec:
      containers:
      - name: mongo
        image: mongo:8.2
        ports:
        - containerPort: 27017
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: mongo-user
        - name: MONGO_INITDB_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: mongo-password
        volumeMounts:
        - name: mongo-storage
          mountPath: /data/db
      volumes:
      - name: mongo-storage
        persistentVolumeClaim:
          claimName: mongo-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: mongo
spec:
  selector:
    app: mongo
  ports:
  - port: 27017
    targetPort: 27017
  type: ClusterIP
```

```bash
kubectl apply -f k8s/mongo-deployment.yaml
```

#### RabbitMQ Deployment

```yaml
# k8s/rabbitmq-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rabbitmq
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rabbitmq
  template:
    metadata:
      labels:
        app: rabbitmq
    spec:
      containers:
      - name: rabbitmq
        image: rabbitmq:4.2-management-alpine
        ports:
        - containerPort: 5672
          name: amqp
        - containerPort: 15672
          name: management
        env:
        - name: RABBITMQ_DEFAULT_USER
          valueFrom:
            secretKeyRef:
              name: rabbitmq-credentials
              key: username
        - name: RABBITMQ_DEFAULT_PASS
          valueFrom:
            secretKeyRef:
              name: rabbitmq-credentials
              key: password
---
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq
spec:
  selector:
    app: rabbitmq
  ports:
  - port: 5672
    targetPort: 5672
    name: amqp
  - port: 15672
    targetPort: 15672
    name: management
  type: ClusterIP
```

```bash
kubectl apply -f k8s/rabbitmq-deployment.yaml
```

### Step 6: Deploy Microservices

#### Broker Service

```yaml
# k8s/broker-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broker-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: broker-service
  template:
    metadata:
      labels:
        app: broker-service
    spec:
      containers:
      - name: broker-service
        image: yourusername/broker-service:latest
        ports:
        - containerPort: 80
        env:
        - name: RABBIT_URL
          value: "amqp://$(RABBITMQ_USER):$(RABBITMQ_PASS)@rabbitmq:5672/"
        - name: RABBITMQ_USER
          valueFrom:
            secretKeyRef:
              name: rabbitmq-credentials
              key: username
        - name: RABBITMQ_PASS
          valueFrom:
            secretKeyRef:
              name: rabbitmq-credentials
              key: password
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /ping
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ping
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: broker-service
spec:
  selector:
    app: broker-service
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer  # or ClusterIP with Ingress
```

```bash
kubectl apply -f k8s/broker-deployment.yaml
```

#### Authentication Service

```yaml
# k8s/auth-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: authentication-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: authentication-service
  template:
    metadata:
      labels:
        app: authentication-service
    spec:
      containers:
      - name: authentication-service
        image: yourusername/auth-service:latest
        ports:
        - containerPort: 80
        env:
        - name: DSN
          value: "host=postgres port=5432 user=$(POSTGRES_USER) password=$(POSTGRES_PASSWORD) dbname=users sslmode=disable timezone=UTC connect_timeout=5"
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: postgres-user
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: postgres-password
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
---
apiVersion: v1
kind: Service
metadata:
  name: authentication-service
spec:
  selector:
    app: authentication-service
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

```bash
kubectl apply -f k8s/auth-deployment.yaml
```

### Step 7: Configure Ingress

```yaml
# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: microservices-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - api.yourdomain.com
    secretName: microservices-tls
  rules:
  - host: api.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: broker-service
            port:
              number: 80
```

```bash
# Install nginx ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Apply ingress
kubectl apply -f k8s/ingress.yaml
```

### Step 8: Deploy Remaining Services

```bash
# Deploy all services
kubectl apply -f k8s/logger-deployment.yaml
kubectl apply -f k8s/mail-deployment.yaml
kubectl apply -f k8s/listener-deployment.yaml
```

### Step 9: Verify Deployment

```bash
# Check all pods
kubectl get pods

# Check services
kubectl get services

# Check ingress
kubectl get ingress

# View logs
kubectl logs -f deployment/broker-service

# Describe pod for troubleshooting
kubectl describe pod <pod-name>
```

### Step 10: Test Deployment

```bash
# Get external IP
kubectl get service broker-service

# Test API
curl -X POST http://<EXTERNAL-IP>/handle \
  -H "Content-Type: application/json" \
  -d '{
    "action": "auth",
    "auth": {
      "email": "admin@example.com",
      "password": "verysecret"
    }
  }'
```

---

## Cloud Providers

### AWS ECS Deployment

#### Prerequisites
- AWS CLI configured
- ECR repository created
- ECS cluster created

```bash
# Authenticate to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build and push
docker build -t <account-id>.dkr.ecr.us-east-1.amazonaws.com/broker-service:latest ./broker-service
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/broker-service:latest

# Create task definition
aws ecs register-task-definition --cli-input-json file://task-definition.json

# Create service
aws ecs create-service \
  --cluster microservices-cluster \
  --service-name broker-service \
  --task-definition broker-service:1 \
  --desired-count 3 \
  --launch-type FARGATE
```

### Google Cloud (GKE)

```bash
# Create GKE cluster
gcloud container clusters create microservices-cluster \
  --num-nodes 3 \
  --machine-type n1-standard-2 \
  --region us-central1

# Get credentials
gcloud container clusters get-credentials microservices-cluster --region us-central1

# Push to GCR
docker tag broker-service gcr.io/PROJECT_ID/broker-service:latest
docker push gcr.io/PROJECT_ID/broker-service:latest

# Deploy to GKE (use k8s manifests above)
kubectl apply -f k8s/
```

### Azure (AKS)

```bash
# Create AKS cluster
az aks create \
  --resource-group myResourceGroup \
  --name microservicesCluster \
  --node-count 3 \
  --enable-addons monitoring \
  --generate-ssh-keys

# Get credentials
az aks get-credentials --resource-group myResourceGroup --name microservicesCluster

# Push to ACR
az acr login --name myregistry
docker tag broker-service myregistry.azurecr.io/broker-service:latest
docker push myregistry.azurecr.io/broker-service:latest

# Deploy to AKS
kubectl apply -f k8s/
```

---

## CI/CD Pipeline

### GitHub Actions Example

```yaml
# .github/workflows/deploy.yml
name: Build and Deploy

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2

    - name: Login to Docker Hub
      uses: docker/login-action@v2
      with:
        username: ${{ secrets.DOCKER_USERNAME }}
        password: ${{ secrets.DOCKER_PASSWORD }}

    - name: Build and push Broker Service
      uses: docker/build-push-action@v4
      with:
        context: ./broker-service
        push: true
        tags: ${{ secrets.DOCKER_USERNAME }}/broker-service:latest

    # Repeat for other services

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3

    - name: Configure kubectl
      uses: azure/k8s-set-context@v3
      with:
        method: kubeconfig
        kubeconfig: ${{ secrets.KUBE_CONFIG }}

    - name: Deploy to Kubernetes
      run: |
        kubectl apply -f k8s/
        kubectl rollout status deployment/broker-service
```

---

## Security Considerations

### Production Checklist

- [ ] Use secrets management (Kubernetes Secrets, AWS Secrets Manager)
- [ ] Enable TLS/SSL for all external endpoints
- [ ] Implement network policies in Kubernetes
- [ ] Use private container registry
- [ ] Enable pod security policies
- [ ] Implement rate limiting
- [ ] Use strong database passwords
- [ ] Enable audit logging
- [ ] Implement JWT authentication
- [ ] Scan container images for vulnerabilities
- [ ] Use non-root container users
- [ ] Implement RBAC in Kubernetes

---

## Monitoring & Logging

### Prometheus & Grafana

```bash
# Install Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack

# Access Grafana
kubectl port-forward svc/prometheus-grafana 3000:80
```

### ELK Stack

```bash
# Install Elasticsearch, Logstash, Kibana
helm repo add elastic https://helm.elastic.co
helm install elasticsearch elastic/elasticsearch
helm install kibana elastic/kibana
```

---

## Backup & Recovery

### Database Backups

```bash
# PostgreSQL backup
kubectl exec -it postgres-pod -- pg_dump -U postgres users > backup.sql

# MongoDB backup
kubectl exec -it mongo-pod -- mongodump --out /backup

# Automated backups with CronJob
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:14-alpine
            command: ["/bin/sh", "-c"]
            args:
            - pg_dump -U postgres -h postgres users | gzip > /backup/backup-$(date +%Y%m%d).sql.gz
```

---

## Rollback Procedures

```bash
# View deployment history
kubectl rollout history deployment/broker-service

# Rollback to previous version
kubectl rollout undo deployment/broker-service

# Rollback to specific revision
kubectl rollout undo deployment/broker-service --to-revision=2

# Check rollback status
kubectl rollout status deployment/broker-service
```

---

## Scaling

### Manual Scaling

```bash
# Scale deployment
kubectl scale deployment broker-service --replicas=5

# Verify scaling
kubectl get deployment broker-service
```

### Auto-scaling (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: broker-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: broker-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

```bash
kubectl apply -f hpa.yaml
kubectl get hpa
```

---

## Support

For deployment issues:
- Check logs: `kubectl logs <pod-name>`
- Describe resources: `kubectl describe <resource> <name>`
- Check events: `kubectl get events`
- Review troubleshooting guide: [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
