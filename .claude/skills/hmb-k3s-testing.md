# HMB K3s & AWS Deployment

Deploy the HMB Flutter web app and API server. Primary target is k3s (self-hosted), with AWS serverless as optional cloud deployment.

## Dual Hosting Strategy

Every service has a self-hosted and cloud option. Build self-hosted first.

| Concern | Self-Hosted (k3s) | AWS Serverless |
| --- | --- | --- |
| Frontend | nginx pod + Traefik ingress | CloudFront + S3 |
| API | FastAPI pod | API Gateway + Lambda |
| Auth | Authentik (existing) | Cognito |
| Database | PostgreSQL 16 StatefulSet | DynamoDB |
| Object Storage | MinIO (S3-compatible) | S3 |
| AI Proxy | LiteLLM (existing) | Lambda → OpenRouter |
| Monitoring | Prometheus + Grafana (existing) | CloudWatch |
| TLS | cert-manager + Let's Encrypt | ACM |

## K3s Deployment (Primary)

### Flutter Web Frontend

```dockerfile
# Stage 1: Build Flutter web
FROM ghcr.io/cirruslabs/flutter:stable AS builder
WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web --release

# Stage 2: Serve with nginx
FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

### K8s Manifests

- Namespace: `hmb`
- Deployment: `Recreate` strategy, single replica
- Service: ClusterIP, port 80
- Ingress: `hmb.k3s.internal.strommen.systems`, TLS via `letsencrypt-prod`
- Pull secret: `harbor-pull-secret`
- Health check: `/healthz`
- ServiceMonitor for Prometheus
- Service selector MUST include `app.kubernetes.io/component: web`

### API Server (Phase 7)

- Python FastAPI or Dart shelf
- PostgreSQL 16 StatefulSet with Longhorn PVC
- MinIO for object storage (S3-compatible API)
- Authentik for auth (JWT validation)
- LiteLLM for AI proxy
- Ingress: `api.hmb.k3s.internal.strommen.systems`

### Build & Deploy

```bash
# Build Docker image (amd64 only, no provenance)
docker buildx build --platform linux/amd64 --provenance=false \
  -t harbor.k3s.internal.strommen.systems/staging/hmb:sha-$(git rev-parse --short HEAD) \
  --push .

# Promote to production
gh workflow run promote-image.yml -f image=hmb -f tag=sha-$(git rev-parse --short HEAD)

# Deploy and verify
kubectl apply -f kubernetes/ && kubectl rollout restart deployment/hmb -n hmb
kubectl get pods,svc,ingress -n hmb
```

## AWS Serverless Deployment (Optional)

### Architecture

```
CloudFront + S3 (Flutter SPA)
  └── /api/* → API Gateway (HTTP API) → Lambda (Python)
                  └── Cognito Authorizer (JWT)
                        ├── Lambda: CRUD (DynamoDB)
                        ├── Lambda: AI Proxy (OpenRouter)
                        ├── Lambda: Sync (push/pull)
                        └── Lambda: File Presign (S3)
```

### Terraform Modules

```
terraform/modules/
  hmb-frontend/    # S3 + CloudFront + OAC + Route53
  hmb-api/         # API Gateway HTTP API + custom domain
  hmb-lambda/      # Lambda functions + IAM + layers + logs
  hmb-dynamodb/    # Single-table design + 2 GSIs
  hmb-cognito/     # User Pool + App Client
  hmb-storage/     # S3 files bucket + lifecycle rules
  hmb-monitoring/  # CloudWatch alarms + dashboard
```

### Cost Estimates

| Scale | Monthly |
| --- | --- |
| 1 user | ~$0.50 |
| 10 users | ~$4 |
| 100 users | ~$34 |

Key: DynamoDB (not Aurora) — $0 free tier vs $43.80/mo Aurora minimum.

### DynamoDB Single-Table Design

```
PK: USER#<userId>  SK: CUST#<custId>      → Customer
PK: CUST#<custId>  SK: JOB#<jobId>        → Job
PK: JOB#<jobId>    SK: INV#<invId>        → Invoice
PK: JOB#<jobId>    SK: QUOTE#<quoteId>    → Quote
PK: USER#<userId>  SK: SYNC#<timestamp>   → SyncLog
```

GSI1 for inverse lookups, GSI2 for status/date queries.

## Considerations

- **Private onepub.dev deps**: Must fork/vendor before builds work
- **SQLite WASM**: Test persistence across browser sessions
- **OAuth redirects**: Need web-specific redirect URIs
- **Mobile-only features**: Camera, dialer, notifications — graceful degradation in web
- **CORS**: If web app calls external APIs directly, CORS headers needed
- **Offline sync**: App works fully offline; server is sync target, not source of truth
